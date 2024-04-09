# frozen_string_literal: true

module Shipit
  class RollbackSerializer < DeploySerializer
    def type
      :rollback
    end

    def include_rollback_url?
      false
    end
  end
end
