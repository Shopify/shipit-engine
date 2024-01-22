# frozen_string_literal: true

require 'test_helper'

module Shipit
  class UpdateGithubLastDeployedRefJobTest < ActiveSupport::TestCase
    Struct.new('ResponseInner', :sha, :type, :url)
    Struct::ResponseInner.superclass
    Struct.new('Response', :ref, :node_id, :url, :object)
    Struct::Response.superclass

    setup do
      @stack = shipit_stacks(:shipit)
      @job = UpdateGithubLastDeployedRefJob.new
      @deploy = @stack.deploys.last
      @commit = @deploy.until_commit
      @api_client = Shipit.github.api
      @expected_name = @stack.github_repo_name
      @expected_sha = @commit.sha

      expected_ref_suffix = "shipit-deploy/#{@stack.environment}"
      @expected_ref = ["heads", expected_ref_suffix].join('/')

      ref_url = "http://api.github.test.com/shopify/shipit-engine/git/#{@expected_ref}"
      commit_url = "https://api.github.test.com/repos/shopify/shipit-engine/git/commits/#{@commit.sha}"
      response_inner_obj = Struct::ResponseInner.new(@commit.sha, "commit", commit_url)
      @response = Struct::Response.new(@expected_ref, "blah", ref_url, response_inner_obj)
    end

    test "#perform will create a ref when one is not present" do
      Octokit::UnprocessableEntity.any_instance.stubs(:build_error_message).returns("Reference does not exist")

      @api_client.expects(:update_ref).with(@expected_name, @expected_ref, @expected_sha).raises(Octokit::UnprocessableEntity)
      @api_client.expects(:create_ref).with(@expected_name, @expected_ref, @expected_sha).returns(@response)

      result = @job.perform(@stack)

      assert_equal @response, result
    end

    test "#perform will update a ref when one is present" do
      prior_response = @response.dup
      prior_response.object = prior_response.object.dup
      new_sha = "some_new_sha"
      @response.object.sha = new_sha
      @commit.sha = new_sha
      @commit.save

      @api_client.expects(:update_ref).with(@expected_name, @expected_ref, new_sha).returns(@response)

      result = @job.perform(@stack)

      assert_equal @response, result
    end

    test '#perform will raise an exception for non ref existence errors' do
      Octokit::UnprocessableEntity.any_instance.stubs(:build_error_message).returns("Some other error.")

      @api_client.expects(:update_ref).with(@expected_name, @expected_ref, @expected_sha).raises(Octokit::UnprocessableEntity)
      @api_client.expects(:create_ref).with(@expected_name, @expected_ref, @expected_sha).never

      assert_raises Octokit::UnprocessableEntity do
        @job.perform(@stack)
      end
    end

    test '#perform skips unsuccessful deploys when finding sha to use' do
      prior_response = @response.dup
      prior_response.object = prior_response.object.dup
      new_sha = "some_new_sha"
      @response.object.sha = new_sha
      @commit.sha = new_sha
      @commit.save

      new_deploy = @stack.deploys.last.dup
      new_commit = new_deploy.until_commit.dup
      new_commit.sha = "some fake sha"
      new_deploy.until_commit = new_commit
      new_deploy.id = nil
      new_deploy.status = "faulty"
      new_deploy.save

      @api_client.expects(:update_ref).with(@expected_name, @expected_ref, new_sha).returns(@response)
      result = @job.perform(@stack)

      assert_equal @response, result

      new_deploy.reload
      new_deploy.status = "success"
      new_deploy.save

      @api_client.expects(:update_ref).with(@expected_name, @expected_ref, new_commit.sha).returns(@response)
      @job.perform(@stack)
    end
  end
end
