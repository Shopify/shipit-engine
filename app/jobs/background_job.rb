class BackgroundJob

  class << self

    attr_accessor :timeout

    def perform(*args)
      if options = args.extract_options!
        args = [*args, options.with_indifferent_access]
      end

      with_timeout do
        new.perform(*args)
      end
    end

    private

    def with_timeout(&block)
      return yield unless timeout
      Timeout.timeout(timeout, &block)
    end

  end

  def logger
    Rails.logger
  end
end
