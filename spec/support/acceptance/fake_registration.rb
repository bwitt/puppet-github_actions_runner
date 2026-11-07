# frozen_string_literal: true

require 'yaml'

# Default root dir, versioned with the runner version from Hiera
RUNNER_ROOT_DIR = "/opt/actions-runner-#{YAML.load_file(File.expand_path('../../../data/common.yaml', __dir__))['github_actions_runner::package_ensure']}"

# Registering a runner needs a real GitHub token. Pretend the instance is
# already registered, so the module skips config.sh, and provide a dummy
# runsvc.sh for the service to run.
def fake_runner_registration(instance_dir, user = 'root')
  shell("mkdir -p #{instance_dir} && touch #{instance_dir}/.credentials")
  shell("printf '#!/bin/sh\\nexec sleep infinity\\n' > #{instance_dir}/runsvc.sh && chmod 0755 #{instance_dir}/runsvc.sh")
  shell("chown -R #{user}:#{user} #{instance_dir}")
end
