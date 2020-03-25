# typed: false
require 'test_helper'

module Shipit
  class RepositoryTest < ActiveSupport::TestCase
    setup do
      @repository = shipit_repositories(:shipit)
    end

    test "owner, and name uniqueness is enforced" do
      clone = Repository.new(@repository.attributes.except('id'))
      refute clone.save
      assert_equal ["cannot be used more than once"], clone.errors[:name]
    end

    test "owner, name, and environment can only be ASCII" do
      @repository.update(owner: 'héllò', name: 'wørld')
      refute_predicate @repository, :valid?
    end

    test "owner and name are case insensitive" do
      assert_no_difference -> { Repository.count } do
        error = assert_raises ActiveRecord::RecordInvalid do
          Repository.create!(
            owner: @repository.owner.upcase,
            name: @repository.name.upcase,
          )
        end
        assert_equal 'Validation failed: Name cannot be used more than once', error.message
      end

      new_repository = Repository.create!(owner: 'FOO', name: 'BAR')
      assert_equal new_repository, Repository.find_by(owner: 'foo', name: 'bar')
    end

    test "owner is automatically downcased" do
      @repository.owner = 'George'
      assert_equal 'george', @repository.owner
    end

    test "name is automatically downcased" do
      @repository.name = 'Cyclim.se'
      assert_equal 'cyclim.se', @repository.name
    end

    test "owner cannot contain a `/`" do
      assert @repository.valid?
      @repository.owner = 'foo/bar'
      refute @repository.valid?
    end

    test "name cannot contain a `/`" do
      assert @repository.valid?
      @repository.name = 'foo/bar'
      refute @repository.valid?
    end

    test "http_url" do
      assert_equal "https://github.com/#{@repository.owner}/#{@repository.name}", @repository.http_url
    end

    test "git_url" do
      assert_equal "https://github.com/#{@repository.owner}/#{@repository.name}.git", @repository.git_url
    end

    test "from_github_repo_name" do
      owner = "repository-owner"
      name = "repository-name"
      github_repo_name = [owner, name].join("/")
      expected_repository = Repository.create(owner: owner, name: name)

      found_repository = Repository.from_github_repo_name(github_repo_name)

      assert_equal(expected_repository, found_repository)
    end
  end
end
