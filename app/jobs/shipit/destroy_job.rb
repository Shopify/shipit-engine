module Shipit
  class DestroyJob < BackgroundJob
    queue_as :default

    def perform(instance)
      instance.destroy
    end
  end
end
