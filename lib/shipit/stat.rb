module Shipit
  module Stat
    extend self

    def p90(numbers)
      percentile(90, numbers)
    end

    def percentile(percentile, numbers)
      numbers.sort[((numbers.size - 1) * percentile / 100.0).floor]
    end
  end
end
