RSpec.describe CommentPolicy do
  let(:anonymous_user) { create(:user_nobody) }
  let(:comment_author) { create(:confirmed_user, login: 'burdenski') }
  let(:admin_user) { create(:admin_user, login: 'admin') }
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:other_user) { create(:confirmed_user, login: 'other_user') }
  let(:project) { create(:project, name: 'CommentableProject') }
  let(:package) { create(:package, :as_submission_source, name: 'CommentablePackage', project: project) }
  let(:comment) { create(:comment_project, commentable: project, user: comment_author) }
  let(:request) { create(:bs_request_with_submit_action, target_package: package) }
  let(:comment_on_package) { create(:comment_package, commentable: package, user: comment_author) }
  let(:comment_on_request) { create(:comment_request, commentable: request, user: comment_author) }
  let(:comment_deleted) { create(:comment_project, commentable: project, user: anonymous_user) }

  subject { CommentPolicy }

  permissions :destroy? do
    it 'Not logged users cannot destroy comments' do
      expect(subject).not_to permit(nil, comment)
    end

    it 'Admin can destroy any comments' do
      expect(subject).to permit(admin_user, comment)
    end

    it 'Users can destroy their own comments' do
      expect(subject).to permit(comment_author, comment)
    end

    it 'Anonymous users cannot destroy already deleted comments' do
      expect(subject).not_to permit(nil, comment_deleted)
    end

    it 'Logged users cannot destroy already deleted comments' do
      expect(subject).not_to permit(comment_author, comment_deleted)
    end

    it 'Admin cannot destroy already deleted comments' do
      expect(subject).not_to permit(admin_user, comment_deleted)
    end

    it 'User cannot destroy comments of other user' do
      expect(subject).not_to permit(user, comment)
    end

    context 'with a comment of a Package' do
      before do
        allow(user).to receive(:has_local_permission?).with('change_package', package).and_return(true)
        allow(other_user).to receive(:has_local_permission?).with('change_package', package).and_return(false)
      end

      it { expect(subject).to permit(user, comment_on_package) }
      it { expect(subject).not_to permit(other_user, comment_on_package) }
    end

    context 'with a comment of a Project' do
      before do
        allow(user).to receive(:has_local_permission?).with('change_project', project).and_return(true)
        allow(other_user).to receive(:has_local_permission?).with('change_project', project).and_return(false)
      end

      it { expect(subject).to permit(user, comment) }
      it { expect(subject).not_to permit(other_user, comment) }
    end

    context 'with a comment of a Request' do
      before do
        allow(request).to receive(:is_target_maintainer?).with(user).and_return(true)
        allow(request).to receive(:is_target_maintainer?).with(other_user).and_return(false)
      end

      it { expect(subject).to permit(user, comment_on_request) }
      it { expect(subject).not_to permit(other_user, comment_on_request) }
    end
  end

  permissions :update? do
    it 'an anonymous user cannot update comments' do
      expect(subject).not_to permit(nil, comment)
    end

    it 'an admin user cannot update other comments' do
      expect(subject).not_to permit(admin_user, comment)
    end

    it 'a user can update their own comments' do
      expect(subject).to permit(comment_author, comment)
    end

    it 'a user cannot update comments of other users' do
      expect(subject).not_to permit(other_user, comment)
    end

    context 'with a deleted comment' do
      it 'a normal user is unable to update a deleted comment' do
        expect(subject).not_to permit(other_user, comment_deleted)
      end

      it 'an admin user is unable to update a deleted comment' do
        expect(subject).not_to permit(admin_user, comment_deleted)
      end

      it 'an anonymous user is unable to update a deleted comment' do
        expect(subject).not_to permit(anonymous_user, comment_deleted)
      end
    end
  end

  permissions :reply? do
    it 'an anonymous user cannot reply to comments' do
      expect(subject).not_to permit(nil, comment)
    end

    it 'an admin user can reply to other comments' do
      expect(subject).to permit(admin_user, comment)
    end

    it 'a user can reply to comments' do
      expect(subject).to permit(comment_author, comment)
    end

    context 'with a deleted comment' do
      it 'a normal user is unable to reply to a deleted comment' do
        expect(subject).not_to permit(other_user, comment_deleted)
      end

      it 'an admin user is unable to reply to a deleted comment' do
        expect(subject).not_to permit(admin_user, comment_deleted)
      end

      it 'an anonymous user is unable to reply to a deleted comment' do
        expect(subject).not_to permit(anonymous_user, comment_deleted)
      end
    end
  end

  permissions :moderate? do
    it 'a not logged-in user cannot moderate comments' do
      expect(subject).not_to permit(nil, comment)
    end

    it 'an anonymous user cannot moderate comments' do
      expect(subject).not_to permit(anonymous_user, comment)
    end

    it 'a non-admin user cannot moderate comments' do
      expect(subject).not_to permit(other_user, comment)
    end

    it 'an admin user can moderate comments' do
      expect(subject).to permit(admin_user, comment)
    end

    context 'with a deleted comment' do
      it 'no one is able to moderate a deleted comment' do
        expect(subject).not_to permit(admin_user, comment_deleted)
      end
    end

    context 'when the moderator is a staff member' do
      let(:staff_user) { create(:staff_user) }

      it 'an staff member can moderate comments' do
        expect(subject).to permit(staff_user, comment)
      end
    end

    context 'when the user has the moderator role assigned' do
      let(:user_with_moderator_role) { create(:moderator) }

      it 'can moderate comments' do
        expect(subject).to permit(user_with_moderator_role, comment)
      end
    end
  end
end
