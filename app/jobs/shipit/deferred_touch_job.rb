# frozen_string_literal: true
module Shipit
  class DeferredTouchJob < BackgroundJob
    include BackgroundJob::Unique

    queue_as :default

    self.timeout = 30
    self.lock_timeout = 15

    def perform
      DeferredTouch.touch_now!
    end
  end
end
