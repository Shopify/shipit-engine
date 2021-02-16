# frozen_string_literal: true
require 'test_helper'

module Shipit
  class CommitSerializerTest < ActiveSupport::TestCase
    test 'commit includes author object' do
      commit = shipit_commits(:first)

      serializer = ActiveModel::Serializer.serializer_for(commit)
      assert_equal CommitSerializer, serializer
      serialized = serializer.new(commit).to_json

      assert_json_document(serialized, "author.name", commit.author.name)
    end
  end
end
