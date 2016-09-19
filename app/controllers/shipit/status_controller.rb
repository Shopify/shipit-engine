module Shipit
  class StatusController < ActionController::Base
    def version
      render plain: Shipit.revision
    end
  end
end
