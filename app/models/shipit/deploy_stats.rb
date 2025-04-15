# frozen_string_literal: true

module Shipit
  class DeployStats
    delegate :empty?, to: :@deploys

    def initialize(deploys)
      @deploys = deploys
      @durations = @deploys.map { |d| d.duration&.value }.compact
    end

    def count
      @deploys.length
    end

    def average_duration
      return if empty?

      @durations.sum / @durations.length.to_f
    end

    def max_duration
      @durations.max
    end

    def min_duration
      @durations.min
    end

    def median_duration
      return if @durations.empty?

      (sorted_durations[(@durations.length - 1) / 2] + sorted_durations[@durations.length / 2]) / 2.0
    end

    def success_rate
      return if empty?

      (@deploys.count(&:success?) / @deploys.length.to_f) * 100
    end

    def compare(compare_stats)
      {
        count: percent_change(compare_stats.count, count),
        average_duration: percent_change(compare_stats.average_duration, average_duration),
        median_duration: percent_change(compare_stats.median_duration, median_duration)
      }
    end

    protected

    def sorted_durations
      @sorted ||= @durations.sort
    end

    def percent_change(from, to)
      return if to.nil? || from.nil?
      return to * 100 if from.zero?

      ((to - from) / from.to_f) * 100
    end
  end
end
