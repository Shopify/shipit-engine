# frozen_string_literal: true

module Shipit
  module LockProviders
    class Provider
      def try_lock
        raise NotImplementedError, "you must implement #try_lock"
      end
    end
  end
end
