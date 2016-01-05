require 'test_helper'

module Shipit
  class GithubHookTest < ActiveSupport::TestCase
    def setup
      @stack = shipit_stacks(:shipit)
      @hook = shipit_github_hooks(:shipit_push)
    end

    test "#verify_signature is true if the signature matches" do
      assert @hook.verify_signature('sha1=9fb52fecc2b97b7a912aca27685149d2ce571900', 'hello shipit')
    end

    test "#verify_signature is false if the signature doesn't match" do
      refute @hook.verify_signature('sha1=9fb52fecc2b97b7a912aca27685149d2ce571900', 'hello toto')
    end

    test "#setup! create the hook on Github side" do
      @hook = shipit_github_hooks(:cyclimse_push)

      response = mock(id: 44, rels: {self: mock(href: 'https://api.github.com/somestuff')})
      Shipit.github_api.expects(:create_hook).with(
        @hook.github_repo_name,
        'web',
        includes(:url, :content_type, :secret),
        includes(:events, :active),
      ).returns(response)
      @hook.setup!
      @hook.reload
      assert_equal 44, @hook.github_id
      assert_equal 'https://api.github.com/somestuff', @hook.api_url
    end

    test "#setup! update the hook it it already exist" do
      response = mock(id: 44, rels: {self: mock(href: 'https://api.github.com/somestuff')})
      Shipit.github_api.expects(:edit_hook).with(
        @hook.github_repo_name,
        @hook.github_id,
        'web',
        includes(:url, :content_type, :secret),
        includes(:events, :active),
      ).returns(response)
      @hook.setup!
      @hook.reload
      assert_equal 44, @hook.github_id
      assert_equal 'https://api.github.com/somestuff', @hook.api_url
    end

    test "#destroy starts by removing the hook" do
      Shipit.github_api.expects(:remove_hook).with(@hook.github_repo_name, @hook.github_id)
      assert_difference -> { GithubHook.count }, -1 do
        @hook.destroy!
      end
    end
  end
end
