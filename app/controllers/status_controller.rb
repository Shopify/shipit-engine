class StatusController < ActionController::Base
  def version
    render text: Shipster.revision
  end
end
