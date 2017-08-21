module Shipit
  class PurgeOldDeliveriesJob < BackgroundJob
    include BackgroundJob::Unique

    queue_as :low

    def perform(hook)
      hook.purge_old_deliveries!
    end
  end
end
