module Shipit
  UnknownStatus = Struct.new(:commit) do
    def state
      'unknown'
    end
    alias_method :simple_state, :state

    def pending?
      false
    end

    def success?
      false
    end

    def error?
      false
    end

    def failure?
      false
    end

    def group?
      false
    end

    def target_url
      nil
    end

    def description
      ''
    end

    def context
      'ci/unknown'
    end

    def to_partial_path
      'shipit/statuses/status'
    end
  end
end
