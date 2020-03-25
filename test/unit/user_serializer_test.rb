# typed: false
require 'test_helper'

module Shipit
  class UserSerializerTest < ActiveSupport::TestCase
    test 'includes anonymous key' do
      user = User.new
      serializer = ActiveModel::Serializer.serializer_for(user)
      assert_equal UserSerializer, serializer
      serialized = serializer.new(user).to_json
      assert_json("anonymous", false, document: serialized)
    end
  end
end
