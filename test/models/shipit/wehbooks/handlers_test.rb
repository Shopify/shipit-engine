# typed: false
require 'test_helper'

module Shipit
  module Webhooks
    class HandlersTest < ActiveSupport::TestCase
      test 'custom handlers do not replace default shipit handlers' do
        event = 'push'
        mock_handler = mock
        Shipit::Webhooks.register_handler(event, mock_handler)

        assert_includes Shipit::Webhooks.for_event(event), mock_handler
        assert_includes Shipit::Webhooks.for_event(event), Shipit::Webhooks::Handlers::PushHandler

        Shipit::Webhooks.reset_handlers!
      end

      test "unknown events have no handlers" do
        event = '_'

        handlers = Shipit::Webhooks.for_event(event)

        assert_equal [], handlers
      end
    end
  end
end
