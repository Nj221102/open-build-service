class WorkflowRunRowComponent < ApplicationComponent
  attr_reader :workflow_run, :status, :hook_event, :hook_action, :repository_name, :repository_url, :event_source_name, :event_source_url, :formatted_event_source_name

  def initialize(workflow_run:)
    super

    @workflow_run = workflow_run
    @status = workflow_run.status
    @hook_event = workflow_run.hook_event || 'unknown'
    @hook_action = workflow_run.hook_action
    @repository_name = workflow_run.repository_full_name
    @repository_url = workflow_run.repository_url
    @event_source_name = workflow_run.event_source_name
    @event_source_url = workflow_run.event_source_url
    @formatted_event_source_name = workflow_run.formatted_event_source_name
  end

  def status_title
    case status
    when 'running'
      'Status: running'
    when 'success'
      'Status: success'
    else
      'Status: failed'
    end
  end

  def status_icon
    classes = case status
              when 'running'
                ['fas', 'fa-running']
              when 'success'
                ['fas', 'fa-check', 'text-primary']
              else
                ['fas', 'fa-exclamation-triangle', 'text-danger']
              end
    classes.join(' ')
  end
end
