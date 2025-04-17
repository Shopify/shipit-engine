# frozen_string_literal: true

module Shipit
  class UnlimitedApiClient
    def stack_id?
      false
    end

    def check_permissions!(*); end
  end
end
