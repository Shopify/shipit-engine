# frozen_string_literal: true

module Shipit
  module LockProviders
    class NullProvider < Provider
      def try_lock
        nil
      end
    end
  end
end
