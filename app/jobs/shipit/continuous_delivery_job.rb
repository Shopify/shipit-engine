module Shipit
  class ContinuousDeliveryJob < BackgroundJob
    include BackgroundJob::Unique

    queue_as :default
    on_duplicate :drop

    def perform(stack)
      # While the `Unique` lock was being acquired it's possible another instance of this job ran and triggered a
      # deploy, in which case we need to reload to ensure these short circuits work.
      stack = stack.reload

      return unless stack.continuous_deployment?
      return if stack.active_task?
      stack.trigger_continuous_delivery
    end
  end
end
