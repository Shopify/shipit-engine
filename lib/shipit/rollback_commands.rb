# frozen_string_literal: true

module Shipit
  class RollbackCommands < DeployCommands
    def steps
      deploy_spec.rollback_steps!
    end

    def env
      super.merge(
        'ROLLBACK' => '1'
      )
    end
  end
end
