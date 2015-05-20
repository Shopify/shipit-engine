class StatusController < ActionController::Base
  def version
    render text: Shipit.revision
  end
end
