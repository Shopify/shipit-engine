require 'test_helper'

module Shipit
  class ReleaseStatusesTest < ActiveSupport::TestCase
    test "" do
      Shipit.github.api.expects(:create_status).once.with(
        'shopify/shipit-engine',
        shipit_commits(:fourth).sha,
        'success',
        context: 'shipit/production', 
        target_url: 'https://example.com/deploys/42',
        description: 'All went well',
      ).returns(resource(id: 42))

      @status = shipit_release_statuses(:to_be_created)
      assert_nil @status.github_id
      @status.create_status_on_github!
      assert_equal 42, @status.github_id
    end
  end
end
