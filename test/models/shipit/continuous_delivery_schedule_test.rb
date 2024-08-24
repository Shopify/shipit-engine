# frozen_string_literal: true
require "test_helper"

module Shipit
  class ContinuousDeliveryScheduleTest < ActiveSupport::TestCase
    test "defaults to all the time" do
      stack = shipit_stacks(:shipit)
      schedule = stack.build_continuous_delivery_schedule

      assert(schedule.valid?)

      Shipit::ContinuousDeliverySchedule::DAYS.each_with_index do |day|
        assert(schedule.read_attribute("#{day}_enabled"))

        day_start = schedule.read_attribute("#{day}_start")
        assert_equal(day_start.at_beginning_of_day, day_start)

        day_end = schedule.read_attribute("#{day}_end")
        assert_equal(day_end.at_end_of_day.at_beginning_of_minute, day_end)
      end
    end

    test "#get_deployment_window" do
      schedule = Shipit::ContinuousDeliverySchedule.new(
        monday_enabled: false,
        monday_start: "09:15",
        monday_end: "17:30",
      )

      monday = Date.current.monday

      deployment_window = schedule.get_deployment_window(monday)

      refute(deployment_window.enabled?)

      starts_at = deployment_window.starts_at
      assert_equal(monday, starts_at.to_date)
      assert_equal(9, starts_at.hour)
      assert_equal(15, starts_at.min)
      assert_equal(starts_at.at_beginning_of_minute, starts_at)

      ends_at = deployment_window.ends_at
      assert_equal(monday, ends_at.to_date)
      assert_equal(17, ends_at.hour)
      assert_equal(30, ends_at.min)
      assert_equal(ends_at.at_end_of_minute, ends_at)
    end

    test "#can_deploy? is false if the day is disabled" do
      schedule = Shipit::ContinuousDeliverySchedule.new(
        tuesday_enabled: false,
        tuesday_start: "00:00",
        tuesday_end: "23:59",
      )

      tuesday = Date.current.monday.advance(days: 1).beginning_of_day

      refute(schedule.can_deploy?(tuesday))
    end

    test "#can_deploy? is true when the current time is within the window" do
      schedule = Shipit::ContinuousDeliverySchedule.new(
        wednesday_enabled: true,
        wednesday_start: "09:15",
        wednesday_end: "17:30",
      )

      wednesday = Date.current.monday.advance(days: 2).beginning_of_day

      refute(schedule.can_deploy?(wednesday))
      assert(schedule.can_deploy?(wednesday.advance(hours: 9, minutes: 15)))
      assert(schedule.can_deploy?(wednesday.advance(hours: 12)))
      assert(schedule.can_deploy?(wednesday.advance(hours: 17, minutes: 30).at_end_of_minute))
      refute(schedule.can_deploy?(wednesday.advance(hours: 17, minutes: 31)))
    end

    test "validates `*_enabled` fields" do
      schedule = Shipit::ContinuousDeliverySchedule.new(
        friday_enabled: nil,
      )

      schedule.validate
      assert_equal(["is not included in the list"], schedule.errors.messages_for(:friday_enabled))
    end

    test "requires `_start` and `_end` fields" do
      schedule = Shipit::ContinuousDeliverySchedule.new(
        saturday_start: nil,
        saturday_end: nil,
      )

      schedule.validate
      assert_equal(["can't be blank"], schedule.errors.messages_for(:saturday_start))
      assert_equal(["can't be blank"], schedule.errors.messages_for(:saturday_end))
    end
  end
end
