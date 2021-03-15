# frozen_string_literal: true
require 'test_helper'

module Shipit
  class AnonymousUserSerializerTest < ActiveSupport::TestCase
    test 'sets anonymous to true' do
      user = AnonymousUser.new
      serializer = ActiveModel::Serializer.serializer_for(user)
      assert_equal AnonymousUserSerializer, serializer
      serialized = serializer.new(user).to_json
      assert_json_document(serialized, "anonymous", true)
    end
  end
end
