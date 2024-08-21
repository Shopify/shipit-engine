# frozen_string_literal: true
require 'test_helper'

module Shipit
  class ContinuousDeliveryJobTest < ActiveSupport::TestCase
    test "calls trigger_continous_delivery" do
      stack = shipit_stacks(:shipit)
      stack.stubs(:continuous_deployment?).returns(true).once
      stack.stubs(:occupied).returns(false).once
      stack.expects(:trigger_continuous_delivery).once

      Shipit::ContinuousDeliveryJob.new.perform(stack)
    end

    test "does not call trigger_continuous_delivery if outside of schedule" do
      freeze_time do
        monday_9am = Date.current.monday.at_beginning_of_day.advance(hours: 9)
        travel_to(monday_9am)

        stack = shipit_stacks(:shipit)
        stack.create_continuous_delivery_schedule!(monday_start: "09:30")

        stack.stubs(:continuous_deployment?).returns(true).once
        stack.expects(:trigger_continuous_delivery).never

        Shipit::ContinuousDeliveryJob.new.perform(stack)
      end
    end
  end
end
