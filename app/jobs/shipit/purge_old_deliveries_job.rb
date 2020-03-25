# typed: false
module Shipit
  class PurgeOldDeliveriesJob < BackgroundJob
    include BackgroundJob::Unique

    queue_as :low
    on_duplicate :drop

    def perform(hook)
      hook.purge_old_deliveries!
    end
  end
end
