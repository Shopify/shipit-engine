module Shipit
  class RollbackSerializer < DeploySerializer
    def type
      :rollback
    end
  end
end
