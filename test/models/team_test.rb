require 'test_helper'

module Shipit
  class TeamTest < ActiveSupport::TestCase
    setup do
      @team = shipit_teams(:shopify_developers)
    end

    test ".find_or_create_by_handle first search in the database" do
      assert_equal @team, Team.find_or_create_by_handle('Shopify/developers')
    end

    test ".find_or_create_by_handle fetch the team from github if it's not in the db already" do
      Shipit.github_api.expects(:org_teams).with('shopify', per_page: 100)
      response = stub(rels: {}, data: [new_team])
      Shipit.github_api.expects(:last_response).returns(response)
      assert_difference -> { Team.count }, 1 do
        Team.find_or_create_by_handle('Shopify/new-team')
      end
    end

    test "#refresh_members! fetch all the team members from github" do
      response = stub(rels: {members: members_resource})
      Shipit.github_api.expects(:get).with(@team.api_url).returns(response)
      assert_difference -> { User.count }, 1 do
        @team.refresh_members!
      end
    end

    private

    def members_resource
      stub(get: stub(data: [george], rels: {}))
    end

    def george
      stub(
        id: 42,
        name: 'George Abitbol',
        login: 'george',
        email: 'george@cyclim.se',
        avatar_url: 'https://avatars.githubusercontent.com/u/42?v=3',
        url: 'https://api.github.com/user/george',
      )
    end

    def new_team
      stub(
        id: 24,
        name: 'New Team',
        slug: 'new-team',
        url: 'https://example.com',
        description: 'The Best one',
        organization: 'shopify',
      )
    end
  end
end
