# frozen_string_literal: true

module Shipit
  class RollbackCommands < DeployCommands
    def steps
      deploy_spec.rollback_steps!
    end

    def failure_step
      return unless deploy_spec.rollback_post.present?

      command = Command.new(deploy_spec.rollback_post, env:, chdir: steps_directory)
      command if command.run_on_error
    end

    def env
      super.merge(
        'ROLLBACK' => '1'
      )
    end
  end
end
