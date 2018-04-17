require 'test_helper'

module Shipit
  class GithubHookTest < ActiveSupport::TestCase
    def setup
      @stack = shipit_stacks(:shipit)
      @hook = shipit_github_hooks(:shipit_push)
    end

    test "#destroy starts by removing the hook" do
      Shipit.legacy_github_api.expects(:remove_hook).with(@hook.github_repo_name, @hook.github_id)
      assert_difference -> { GithubHook.count }, -1 do
        @hook.destroy!
      end
    end
  end
end
