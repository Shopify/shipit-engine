require 'test_helper'

class GithubHookTest < ActiveSupport::TestCase
  def setup
    @webhook = GithubHook.new(secret: '1234')
  end

  test "#verify_signature is true if the signature matches" do
    assert @webhook.verify_signature('sha1=9fb52fecc2b97b7a912aca27685149d2ce571900', 'hello shipit')
  end

  test "#verify_signature is false if the signature doesn't match" do
    refute @webhook.verify_signature('sha1=9fb52fecc2b97b7a912aca27685149d2ce571900', 'hello toto')
  end
end
