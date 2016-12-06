module Shipit
  class DeferredTouchJob < BackgroundJob
    include BackgroundJob::Unique

    def perform
      DeferredTouch.touch_now!
    end
  end
end
