# frozen_string_literal: true
require 'test_helper'

module Shipit
  class ReleaseStatusesTest < ActiveSupport::TestCase
    test "#create_status_on_github! calls GitHub API" do
      Shipit.github.api.expects(:create_status).once.with(
        'shopify/shipit-engine',
        shipit_commits(:canaries_fourth).sha,
        'pending',
        context: 'shipit/canaries',
        target_url: 'https://example.com/deploys/42',
        description: 'Deploy started',
      ).returns(resource(id: 42))

      @status = shipit_release_statuses(:to_be_created)
      assert_nil @status.github_id
      @status.create_status_on_github!
      assert_equal 42, @status.github_id
    end

    test "#create_status_on_github! does nothing if the github_id is alreayd recorded" do
      Shipit.github.api.expects(:create_status).never

      @status = shipit_release_statuses(:created)
      @status.create_status_on_github!
    end
  end
end
