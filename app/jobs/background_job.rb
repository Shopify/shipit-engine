class BackgroundJob
  class << self
    attr_accessor :timeout

    def perform(*args)
      if options = args.extract_options!
        args = [*args, options.with_indifferent_access]
      end

      with_timeout do
        new(*args).perform
      end
    end

    private

    def with_timeout(&block)
      return yield unless timeout
      Timeout.timeout(timeout, &block)
    end
  end

  attr_reader :params

  def initialize(params = {})
    @params = params
  end

  def logger
    Rails.logger
  end
end
