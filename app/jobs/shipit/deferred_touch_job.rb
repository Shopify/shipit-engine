module Shipit
  class DeferredTouchJob < BackgroundJob
    include BackgroundJob::Unique

    queue_as :default

    def perform
      DeferredTouch.touch_now!
    end
  end
end
