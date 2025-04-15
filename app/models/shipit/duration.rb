# frozen_string_literal: true

module Shipit
  class Duration < ActiveSupport::Duration
    ParseError = Class.new(ArgumentError)

    FORMAT = /
      \A
      (?<days>\d+d)?
      (?<hours>\d+h)?
      (?<minutes>\d+m)?
      (?<seconds>\d+s?)?
      \z
    /x
    UNITS = {
      's' => :seconds,
      'm' => :minutes,
      'h' => :hours,
      'd' => :days
    }.freeze

    class << self
      def parse(value)
        return new(-1) if value.to_s == "-1"

        unless match = FORMAT.match(value.to_s)
          raise ParseError, "not a duration: #{value.inspect}"
        end

        parts = []
        UNITS.each_value do |unit|
          if value = match[unit]
            parts << [unit, value.to_i]
          end
        end

        time = ::Time.current
        new(time.advance(parts.to_h) - time, parts)
      end
    end

    def initialize(value, parts = [[:seconds, value]])
      super
    end

    def to_s
      days, seconds_left = value.divmod(1.day.to_i)
      if days > 0
        "#{days}d#{Time.at(seconds_left).utc.strftime('%Hh%Mm%Ss')}"
      else
        Time.at(value).utc.strftime('%Hh%Mm%Ss')[/[^0a-z]\w+/] || '0s'
      end
    end
  end
end
