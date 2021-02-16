# frozen_string_literal: true
module Shipit
  class RollbackSerializer < DeploySerializer
    def type
      :rollback
    end

    def rollback_url
      SKIP
    end
  end
end
