# frozen_string_literal: true

module PayloadsHelper
  def payload(name)
    Shipit::Engine.root.join('test/fixtures/payloads', "#{name}.json").read
  end

  def payload_parsed(name)
    JSON.parse(payload(name))
  end
end
