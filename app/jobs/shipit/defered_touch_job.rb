module Shipit
  class DeferedTouchJob < BackgroundJob
    include BackgroundJob::Unique

    def perform
      DeferedTouch.touch_now!
    end
  end
end
