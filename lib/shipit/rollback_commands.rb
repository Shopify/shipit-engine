module Shipit
  class RollbackCommands < DeployCommands
    def steps
      deploy_spec.rollback_steps!
    end
  end
end
