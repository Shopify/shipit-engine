# frozen_string_literal: true

module Shipit
  class ContinuousDeliverySchedule < Record
    belongs_to(:stack)

    DAYS = %w[sunday monday tuesday wednesday thursday friday saturday].freeze

    validates(
      *DAYS.map { |day| "#{day}_enabled" },
      inclusion: [true, false],
    )

    validates(
      *DAYS.product([:start, :end]).map { |parts| parts.join("_") },
      presence: true
    )

    DeploymentWindow = Struct.new(:starts_at, :ends_at, :enabled) do
      alias_method :enabled?, :enabled
    end

    def can_deploy?(now = Time.current)
      # Make sure time is in the default time zone so weekdays match what is
      # stored in the database.
      now = now.in_time_zone(Time.zone)

      deployment_window = get_deployment_window(now.to_date)

      deployment_window.enabled? &&
        now >= deployment_window.starts_at &&
        now <= deployment_window.ends_at
    end

    def get_deployment_window(date)
      wday_name = DAYS.fetch(date.wday)

      enabled = read_attribute("#{wday_name}_enabled")

      starts_at, ends_at = [:start, :end].map do |bound|
        raw_time = read_attribute("#{wday_name}_#{bound}")

        # `ActiveRecord::Type::Time` attributes are stored as timestamps
        # normalized to 2000-01-01 so they can't be used for comparisons without
        # having their dates adjusted.
        # https://github.com/rails/rails/blob/ec667e5f114df58087493096253541f1034815af/activemodel/lib/active_model/type/time.rb#L23
        Time.zone.local(
          date.year,
          date.month,
          date.day,
          raw_time.hour,
          raw_time.min,
        )
      end

      DeploymentWindow.new(
        starts_at,
        # Includes the full minute in the configured range. This is required so
        # that a window configured to end at 17:59 actually ends at 17:59:59
        # instead of 17:59:00.
        ends_at.at_end_of_minute,
        enabled,
      )
    end
  end
end
