require 'test_helper'

class RemoteWebhookTest < ActiveSupport::TestCase
  def setup
    @remote_webhook = RemoteWebhook.new(secret: '1234')
  end

  test "#verify_signature is true if the signature matches" do
    assert @remote_webhook.verify_signature('sha1=9fb52fecc2b97b7a912aca27685149d2ce571900', 'hello shipit')
  end

  test "#verify_signature is false if the signature doesn't match" do
    refute @remote_webhook.verify_signature('sha1=9fb52fecc2b97b7a912aca27685149d2ce571900', 'hello toto')
  end
end
