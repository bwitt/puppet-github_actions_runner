# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'github_actions_runner' do
  context 'with defaults' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) { 'include github_actions_runner' }
    end

    describe file(RUNNER_ROOT_DIR) do
      it { is_expected.to be_directory }
      it { is_expected.to be_owned_by 'root' }
    end
  end

  context 'with an instance' do
    before(:all) do
      fake_runner_registration("#{RUNNER_ROOT_DIR}/test")
    end

    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        class { 'github_actions_runner':
          org_name              => 'voxpupuli',
          personal_access_token => 'not-a-real-token',
          instances             => {
            'test' => {
              repo_name => 'puppet-github_actions_runner',
              labels    => ['acceptance', 'test'],
              path      => ['/usr/local/bin', '/usr/bin', '/bin'],
              env       => { 'FOO' => 'bar' },
            },
          },
        }
        PUPPET
      end
    end

    describe file("#{RUNNER_ROOT_DIR}/test") do
      it { is_expected.to be_directory }
      it { is_expected.to be_mode 750 }
      it { is_expected.to be_owned_by 'root' }
    end

    describe file("#{RUNNER_ROOT_DIR}/test/config.sh") do
      it { is_expected.to be_file }
      it { is_expected.to be_executable }
    end

    describe file("#{RUNNER_ROOT_DIR}/test/bin/Runner.Listener") do
      it { is_expected.to be_file }
    end

    describe file("#{RUNNER_ROOT_DIR}/test/configure_install_runner.sh") do
      it { is_expected.to be_file }
      it { is_expected.to be_mode 755 }
      its(:content) { is_expected.to match %r{https://api\.github\.com/repos/voxpupuli/puppet-github_actions_runner/actions/runners/registration-token} }
      its(:content) { is_expected.to match %r{--url https://github\.com/voxpupuli/puppet-github_actions_runner } }
      its(:content) { is_expected.to match %r{--labels acceptance,test} }
    end

    describe file("#{RUNNER_ROOT_DIR}/test/.path") do
      its(:content) { is_expected.to eq "/usr/local/bin:/usr/bin:/bin\n" }
    end

    describe file("#{RUNNER_ROOT_DIR}/test/.env") do
      its(:content) { is_expected.to eq "FOO=bar\n" }
    end

    describe file('/etc/systemd/system/github-actions-runner.test.service') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match %r{^ExecStart=#{RUNNER_ROOT_DIR}/test/runsvc\.sh$} }
      its(:content) { is_expected.to match %r{^WorkingDirectory=#{RUNNER_ROOT_DIR}/test$} }
      its(:content) { is_expected.to match %r{^User=root$} }
    end

    describe service('github-actions-runner.test') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end
  end

  context 'with an instance run by a managed user' do
    before(:all) do
      # the files config.sh would create are owned by the runner user
      shell('id github-runner || useradd --system --user-group github-runner')
      fake_runner_registration("#{RUNNER_ROOT_DIR}/managed", 'github-runner')
    end

    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        class { 'github_actions_runner':
          org_name              => 'voxpupuli',
          personal_access_token => 'not-a-real-token',
          users                 => {
            'github-runner' => {},
          },
          instances             => {
            'managed' => {
              user  => 'github-runner',
              group => 'github-runner',
            },
          },
        }
        PUPPET
      end
    end

    describe user('github-runner') do
      it { is_expected.to exist }
      it { is_expected.to belong_to_primary_group 'github-runner' }
      it { is_expected.to have_home_directory '/home/github-runner' }
    end

    describe file("#{RUNNER_ROOT_DIR}/managed") do
      it { is_expected.to be_directory }
      it { is_expected.to be_owned_by 'github-runner' }
      it { is_expected.to be_grouped_into 'github-runner' }
    end

    describe file("#{RUNNER_ROOT_DIR}/managed/config.sh") do
      it { is_expected.to be_owned_by 'github-runner' }
    end

    describe file("#{RUNNER_ROOT_DIR}/managed/configure_install_runner.sh") do
      its(:content) { is_expected.to match %r{https://api\.github\.com/orgs/voxpupuli/actions/runners/registration-token} }
      its(:content) { is_expected.to match %r{--url https://github\.com/voxpupuli } }
    end

    describe file('/etc/systemd/system/github-actions-runner.managed.service') do
      its(:content) { is_expected.to match %r{^User=github-runner$} }
      its(:content) { is_expected.to match %r{^Group=github-runner$} }
    end

    describe service('github-actions-runner.managed') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end
  end
end
