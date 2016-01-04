module Shipit
  class DestroyStackJob < BackgroundJob
    queue_as :default

    def perform(stack)
      stack.destroy!
    end
  end
end
