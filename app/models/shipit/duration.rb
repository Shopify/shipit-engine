module Shipit
  class Duration
    UNITS = {
      's' => :seconds,
      'm' => :minutes,
      'h' => :hours,
      'd' => :days,
    }.freeze

    def initialize(seconds)
      @seconds = seconds
    end

    def to_i
      @seconds.to_i
    end

    def to_s
      seconds = to_i
      days, seconds = seconds.divmod(1.day.to_i)
      if days > 0
        "#{days}d#{Time.at(seconds).utc.strftime('%Hh%Mm%Ss')}"
      else
        Time.at(seconds).utc.strftime('%Hh%Mm%Ss')[/[^0a-z]\w+/] || '0s'
      end
    end
  end
end
