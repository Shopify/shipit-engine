class BackgroundJob < ActiveJob::Base
  class << self
    attr_accessor :timeout
  end

  def perform(*)
    with_timeout do
      super
    end
  end

  private

  def with_timeout(&block)
    return yield unless timeout
    Timeout.timeout(timeout, &block)
  end

  def logger
    Rails.logger
  end
end
