RSpec.describe UpdatePackagesIfDirtyJob, :vcr do
  include ActiveJob::TestHelper

  describe '#perform' do
    context 'the project is found' do
      let!(:project) { create(:project, name: 'apache') }
      let!(:package) { create(:package_with_file, project: project, name: 'mod_ssl') }

      subject { UpdatePackagesIfDirtyJob.new.perform(project.id) }

      it 'creates a BackendPackge for the Package' do
        expect { subject }.to change(BackendPackage, :count).by(1)
      end
    end

    context 'the project is not found' do
      subject { UpdatePackagesIfDirtyJob.new.perform(123) }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end
end
