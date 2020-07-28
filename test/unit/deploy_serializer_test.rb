# frozen_string_literal: true
require 'test_helper'

module Shipit
  class DeploySerializerTest < ActiveSupport::TestCase
    test 'deploy commits includes author object' do
      deploy = shipit_deploys(:shipit)
      first_commit_author = deploy.commits.first.author

      serializer = ActiveModel::Serializer.serializer_for(deploy)
      assert_equal DeploySerializer, serializer
      serialized = serializer.new(deploy).to_json

      assert_json("commits.0.author.name", first_commit_author.name, document: serialized)
    end
  end
end
