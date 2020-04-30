# frozen_string_literal: true
require 'test_helper'

module Shipit
  class DeployStatsTest < ActiveSupport::TestCase
    def setup
      @stack = shipit_stacks(:shipit_stats)
      @stats = Shipit::DeployStats.new(@stack.deploys.not_active)
      @old_deploys = @stack.deploys.not_active.where(created_at: 62.minutes.ago..32.minutes.ago)
      @new_deploys = @stack.deploys.not_active.where("created_at > ?", 32.minutes.ago)
    end

    test "#average_duration is accurate" do
      assert_equal 225.0, @stats.average_duration
    end

    test "#median_duration is accurate" do
      assert_equal 210.0, @stats.median_duration
    end

    test "#max_duration is accurate" do
      assert_equal 360.0, @stats.max_duration
    end

    test "#min_duration is accurate" do
      assert_equal 120.0, @stats.min_duration
    end

    test "#success_rate is accurate" do
      assert_equal 75.0, @stats.success_rate
    end

    test "#average_duration handles empty deploy data" do
      stats = Shipit::DeployStats.new([])
      assert_nil stats.average_duration
    end

    test "#median_duration handles empty deploy data" do
      stats = Shipit::DeployStats.new([])
      assert_nil stats.median_duration
    end

    test "#max_duration handles empty deploy data" do
      stats = Shipit::DeployStats.new([])
      assert_nil stats.max_duration
    end

    test "#min_duration handles empty deploy data" do
      stats = Shipit::DeployStats.new([])
      assert_nil stats.min_duration
    end

    test "#success_rate handles empty deploy data" do
      stats = Shipit::DeployStats.new([])
      assert_nil stats.success_rate
    end

    test "#compare count handles empty compare count" do
      comparison = Shipit::DeployStats.new([])
      results = @stats.compare(comparison)
      assert_equal 400, results[:count]
    end

    test "#compare average and median handles empty array" do
      comparison = Shipit::DeployStats.new([])
      results = @stats.compare(comparison)
      assert_nil results[:average_duration]
      assert_nil results[:median_duration]
    end

    test "#compare average is accurate when negative" do
      new_data = Shipit::DeployStats.new(@new_deploys)
      old_data = Shipit::DeployStats.new(@old_deploys)
      results = new_data.compare(old_data)
      assert_equal(-53.84615384615385, results[:average_duration])
    end

    test "#compare median is accurate when negative" do
      new_data = Shipit::DeployStats.new(@new_deploys)
      old_data = Shipit::DeployStats.new(@old_deploys)
      results = new_data.compare(old_data)
      assert_equal(-50, results[:median_duration])
    end

    test "#compare count is accurate when negative" do
      new_data = Shipit::DeployStats.new(@new_deploys)
      old_data = Shipit::DeployStats.new(@old_deploys)
      results = new_data.compare(old_data)
      assert_equal(-66.66666666666666, results[:count])
    end

    test "#compare average is accurate" do
      old_data = Shipit::DeployStats.new(@new_deploys)
      new_data = Shipit::DeployStats.new(@old_deploys)
      results = new_data.compare(old_data)
      assert_equal(116.66666666666667, results[:average_duration])
    end

    test "#compare median is accurate" do
      old_data = Shipit::DeployStats.new(@new_deploys)
      new_data = Shipit::DeployStats.new(@old_deploys)
      results = new_data.compare(old_data)
      assert_equal(100, results[:median_duration])
    end

    test "#compare count is accurate" do
      old_data = Shipit::DeployStats.new(@new_deploys)
      new_data = Shipit::DeployStats.new(@old_deploys)
      results = new_data.compare(old_data)
      assert_equal(200, results[:count])
    end
  end
end
