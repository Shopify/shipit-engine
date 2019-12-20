module Shipit
  module Webhooks
    class << self
      attr_accessor :extra_handlers
    end

    self.extra_handlers = []

    def self.register_handler(&block)
      self.extra_handlers << block
    end
  end
end
