# rubocop:disable Metrics/ClassLength

class WorkflowRun < ApplicationRecord
  SOURCE_URL_PAYLOAD_MAPPING = {
    'pull_request' => ['pull_request', 'html_url'],
    'Merge Request Hook' => ['object_attributes', 'url'],
    'push' => ['head_commit', 'url'],
    'Push Hook' => ['commits', 0, 'url']
  }.freeze

  PERMITTED_OPTIONS = [
    # Permitted keys for GitHub
    :api_endpoint, :target_repository_full_name, :commit_sha,
    # Permitted keys for GitLab
    :endpoint, :project_id, :commit_sha,
    # both GitHub and GitLab
    :state, :status_options
  ].freeze

  validates :scm_vendor, :response_url,
            :workflow_configuration_path, :workflow_configuration_url,
            :hook_event, :hook_action, :generic_event_type,
            :repository_name, :repository_owner, :event_source_name, length: { maximum: 255 }
  validates :request_headers, :status, presence: true
  validates :workflow_configuration, length: { maximum: 65_535 }

  belongs_to :token, class_name: 'Token::Workflow', optional: true
  has_many :artifacts, class_name: 'WorkflowArtifactsPerStep', dependent: :destroy
  has_many :scm_status_reports, class_name: 'SCMStatusReport', dependent: :destroy
  has_many :event_subscriptions, dependent: :destroy

  after_save :create_event, if: :status_changed_to_fail?

  paginates_per 20

  enum status: {
    running: 0,
    success: 1,
    fail: 2
  }

  # Marks the workflow run as failed and records the relevant debug information in response_body
  def update_as_failed(message)
    update(response_body: message, status: 'fail')
  end

  # Stores debug info to help figure out what went wrong when trying to save a Status in the SCM.
  # Marks the workflow run as failed also.
  def save_scm_report_failure(message, options)
    update_as_failed(message)
    scm_status_reports.create(response_body: message,
                              request_parameters: JSON.generate(options.slice(*PERMITTED_OPTIONS)),
                              status: 'fail') # set SCMStatusReport status
  end

  # Stores info from a succesful SCM status report. The default value for 'status' is 'success'.
  def save_scm_report_success(options)
    scm_status_reports.create(request_parameters: JSON.generate(options.slice(*PERMITTED_OPTIONS)))
  end

  def payload
    JSON.parse(request_payload.presence || {})
  rescue JSON::ParserError
    { payload: 'unparseable' }
  end

  def repository_full_name
    return unless repository_owner && repository_name

    "#{repository_owner}/#{repository_name}"
  end

  def repository_url
    payload.dig('repository', 'html_url') || # For GitHub and Gitea on pull_request and push events
      payload.dig('project', 'web_url') # For GitLab on merge request and push events
  end

  def event_source_url
    mapped_source_url = SOURCE_URL_PAYLOAD_MAPPING[hook_event]
    payload.dig(*mapped_source_url) if mapped_source_url
  end

  def event_source_message
    case generic_event_type
    when 'pull_request'
      pull_request_message
    when generic_event_type == 'push'
      push_message
    when generic_event_type == 'tag_push'
      tag_push_message
    end
  end

  def last_response_body
    scm_status_reports.last&.response_body
  end

  def configuration_source
    [workflow_configuration_url, workflow_configuration_path].filter_map(&:presence).first
  end

  def formatted_event_source_name
    case hook_event
    when 'pull_request', 'Merge Request Hook'
      "##{event_source_name}"
    else
      event_source_name
    end
  end

  # Examples of summary:
  #   Pull request #234, opened
  #   Merge request hook #234, open
  #   Push 0940857924387654354986745938675645365436
  #   Tag push hook Unknown source
  def summary
    str = "#{hook_event&.humanize || 'unknown'} #{formatted_event_source_name}"
    str += ", #{hook_action.humanize.downcase}" if hook_action.present?
    str
  end

  private

  def event_parameters
    { id: id, token_id: token_id, hook_event: hook_event&.humanize || 'unknown', summary: summary, repository_full_name: repository_full_name }
  end

  def create_event
    Event::WorkflowRunFail.create(event_parameters)
  end

  def status_changed_to_fail?
    saved_change_to_status? && status == 'fail'
  end

  def pull_request_message
    case scm_vendor
    when 'github', 'gitea'
      title = payload.dig('pull_request', 'title')
      body = payload.dig('pull_request', 'body')
      "#{title}\n#{body}"
    when 'gitlab'
      title = payload.dig('object_attributes', 'title')
      body = payload.dig('object_attributes', 'description')
      "#{title}\n#{body}"
    end
  end

  def push_message
    case scm_vendor
    when 'github', 'gitea'
      payload.dig('head_commit', 'message')
    when 'gitlab'
      payload.dig('commits', 0, 'message')
    end
  end

  # FIXME: How to get the real commit message for tag_push?
  def tag_push_message
    "Tag #{payload['ref']} got pushed"
  end
end

# == Schema Information
#
# Table name: workflow_runs
#
#  id                          :integer          not null, primary key
#  event_source_name           :string(255)
#  generic_event_type          :string(255)
#  hook_action                 :string(255)
#  hook_event                  :string(255)
#  repository_name             :string(255)
#  repository_owner            :string(255)
#  request_headers             :text(65535)      not null
#  request_payload             :text(4294967295) not null
#  response_body               :text(65535)
#  response_url                :string(255)
#  scm_vendor                  :string(255)
#  status                      :integer          default("running"), not null
#  workflow_configuration      :text(65535)
#  workflow_configuration_path :string(255)
#  workflow_configuration_url  :string(255)
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  token_id                    :integer          not null, indexed
#
# Indexes
#
#  index_workflow_runs_on_token_id  (token_id)
#
# rubocop:enable Metrics/ClassLength
