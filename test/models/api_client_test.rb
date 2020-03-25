# typed: false
require 'test_helper'

module Shipit
  class ApiClientTest < ActiveSupport::TestCase
    setup do
      @client = shipit_api_clients(:spy)
    end

    test "#authentication_token is the signed id" do
      assert_match(/^\d+--[\da-f]{40}$/, @client.authentication_token)
    end

    test "#authentication_token casted as integer is the client id" do
      assert_equal @client.id, @client.authentication_token.to_i
    end

    test ".authenticate returns nil if the signature is invalid" do
      assert_nil ApiClient.authenticate("#{@client.id}--foobar")
    end

    test ".authenticate returns nil if the api client do not exists" do
      assert_nil ApiClient.authenticate(ApiClient.new(id: 42).authentication_token)
    end

    test ".authenticate returns the matching ApiClient record if the token is valid" do
      assert_equal @client, ApiClient.authenticate(@client.authentication_token)
    end
  end
end
