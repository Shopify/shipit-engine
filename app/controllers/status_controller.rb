class StatusController < ActionController::Base
  def version
    render text: Shipit.revision
  end

  def ping
    render text: 'PONG'
  end
end
