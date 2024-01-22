# frozen_string_literal: true

require 'test_helper'

module Shipit
  class PurgeOldDeliveriesJobTest < ActiveSupport::TestCase
    setup do
      @hook = shipit_hooks(:shipit_deploys)
      @job = PurgeOldDeliveriesJob.new
    end

    test "calls #purge_old_deliveries! on the hook" do
      @hook.expects(:purge_old_deliveries!).once
      @job.perform(@hook)
    end
  end
end
