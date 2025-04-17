# frozen_string_literal: true

require 'test_helper'

module Shipit
  class ContinuousDeliverySchedulesControllerTest < ActionController::TestCase
    setup do
      @routes = Shipit::Engine.routes
      @stack = shipit_stacks(:shipit)
      session[:user_id] = shipit_users(:walrus).id
    end

    def valid_params
      Shipit::ContinuousDeliverySchedule::DAYS.each_with_object({}) do |day, hash|
        hash[:"#{day}_enabled"] = "0"
        hash[:"#{day}_start"] = "09:00"
        hash[:"#{day}_end"] = "17:00"
      end
    end

    test "#show returns a 200 response" do
      get(:show, params: { id: @stack.to_param })

      assert(response.ok?)
    end

    test "#update" do
      patch(:update, params: {
              id: @stack.to_param,
              continuous_delivery_schedule: {
          **valid_params
              }
            })

      assert_redirected_to(stack_continuous_delivery_schedule_path(@stack))
      assert_equal("Successfully updated", flash[:success])

      schedule = @stack.continuous_delivery_schedule

      Shipit::ContinuousDeliverySchedule::DAYS.each do |day|
        refute(schedule.read_attribute("#{day}_enabled"))

        day_start = schedule.read_attribute("#{day}_start")
        assert_equal("09:00:00 AM", day_start.strftime("%r"))

        day_end = schedule.read_attribute("#{day}_end")
        assert_equal("05:00:00 PM", day_end.strftime("%r"))
      end
    end

    test "#update renders validation errors" do
      patch(:update, params: {
              id: @stack.to_param,
              continuous_delivery_schedule: {
          # Make Sunday end before it starts
          **valid_params.merge(sunday_end: "08:00")
              }
            })

      assert_response(:unprocessable_entity)
      assert_equal("Check form for errors", flash[:warning])
      elements = assert_select(".validation-errors")
      assert_includes(elements.sole.inner_text, "Sunday end must be after start (09:00 AM)")
    end
  end
end
