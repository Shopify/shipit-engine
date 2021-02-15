# frozen_string_literal: true
require 'test_helper'

module Shipit
  class UserSerializerTest < ActiveSupport::TestCase
    test 'includes anonymous key' do
      user = User.new
      serializer = Serializer.for(user)
      assert_equal UserSerializer, serializer
      serialized = serializer.new.serialize(user).to_json
      assert_json("anonymous", false, document: serialized)
    end
  end
end
