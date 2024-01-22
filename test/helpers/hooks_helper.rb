# frozen_string_literal: true

module HooksHelper
  def expect_hook(event, stack = nil, payload = nil)
    spy_on_hook
    yield
    assert_received_with(Shipit::Hook, :emit) do |call|
      if call.args.first == event && (stack.nil? || call.args.second == stack)
        if payload.respond_to?(:call)
          payload.call(call.args.third)
        elsif payload
          payload == call.args.third
        else
          true
        end
      end
    end
  end

  def expect_no_hook(*args)
    spy_on_hook
    yield
    spy = Spy::Subroutine.get(Shipit::Hook, :emit)
    called = spy.calls.find do |call|
      args.map.with_index.all? { |value, index| value == call.args[index] }
    end
    matcher = args.map(&:inspect).join(', ')
    got = called&.args&.map(&:inspect)&.join(', ')
    refute(called, "Expected no hook matching: (#{matcher})\n  got: (#{got})")
  end

  private

  def spy_on_hook
    Spy.on(Shipit::Hook, :emit).and_call_through
  rescue Spy::AlreadyHookedError
  end
end
