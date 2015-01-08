require 'test_helper'

class DeploySpecTest < ActiveSupport::TestCase
  setup do
    @spec = DeploySpec::FileSystem.new('/tmp/', 'env')
    @spec.stubs(:load_config).returns({})
  end

  test '#supports_fetch_deployed_revision? returns false by default' do
    refute @spec.supports_fetch_deployed_revision?
  end

  test '#supports_fetch_deployed_revision? returns true if steps are defined' do
    @spec.stubs(:load_config).returns('fetch' => ['curl --silent https://example.com/status/version'])
    assert @spec.supports_fetch_deployed_revision?
  end

  test '#supports_rollback? returns false by default' do
    refute @spec.supports_rollback?
  end

  test '#supports_rollback? returns true if steps are defined' do
    @spec.stubs(:load_config).returns('rollback' => {'override' => ['rm -rf /usr /lib/nvidia-current/xorg/xorg']})
    assert @spec.supports_rollback?
  end

  test '#supports_rollback? returns true if stack is detected as capistrano' do
    @spec.expects(:capistrano?).returns(true)
    assert @spec.supports_rollback?
  end

  test '#dependencies_steps returns `dependencies.override` if present' do
    @spec.stubs(:load_config).returns('dependencies' => {'override' => %w(foo bar baz)})
    assert_equal %w(foo bar baz), @spec.dependencies_steps
  end

  test '#dependencies_steps returns `bundle install` if a `Gemfile` is present' do
    @spec.expects(:bundler?).returns(true)
    @spec.expects(:bundle_install).returns(:bundle_install)
    assert_equal :bundle_install, @spec.dependencies_steps
  end

  test '#fetch_deployed_revision_steps! is unknown by default' do
    assert_raises DeploySpec::Error do
      @spec.fetch_deployed_revision_steps!
    end
  end

  test '#fetch_deployed_revision_steps use `fetch` is present' do
    @spec.stubs(:load_config).returns('fetch' => ['echo l33t'])
    assert_equal ['echo l33t'], @spec.fetch_deployed_revision_steps
  end

  test '#bundle_install return a sane default bundle install command' do
    @spec.stubs(:has_gemfile_lock?).returns(true)
    command = %(
      bundle check --path=#{DeploySpec::BUNDLE_PATH} ||
      bundle install
      --frozen
      --path=#{DeploySpec::BUNDLE_PATH}
      --retry=2
      --without=default:production:development:test:staging:benchmark:debug
    ).gsub(/\s+/, ' ').strip
    assert_equal command, @spec.bundle_install.last
  end

  test '#bundle_install use `dependencies.bundler.without` if present to build the --without argument' do
    @spec.stubs(:has_gemfile_lock?).returns(true)
    @spec.stubs(:load_config).returns('dependencies' => {'bundler' => {'without' => %w(some custom groups)}})
    command = %(
      bundle check --path=#{DeploySpec::BUNDLE_PATH} ||
      bundle install
      --frozen
      --path=#{DeploySpec::BUNDLE_PATH}
      --retry=2
      --without=some:custom:groups
    ).gsub(/\s+/, ' ').strip
    assert_equal command, @spec.bundle_install.last
  end

  test '#bundle_install has --frozen option if Gemfile.lock is present' do
    @spec.stubs(:load_config).returns('dependencies' => {'bundler' => {'without' => %w(some custom groups)}})
    @spec.stubs(:has_gemfile_lock?).returns(true)
    assert @spec.bundle_install.last.include?('--frozen')
  end

  test '#bundle_install does not have --frozen option if Gemfile.lock is not present' do
    @spec.stubs(:load_config).returns('dependencies' => {'bundler' => {'without' => %w(some custom groups)}})
    @spec.stubs(:has_gemfile_lock?).returns(false)
    refute @spec.bundle_install.last.include?('--frozen')
  end

  test '#deploy_steps returns `deploy.override` if present' do
    @spec.stubs(:load_config).returns('deploy' => {'override' => %w(foo bar baz)})
    assert_equal %w(foo bar baz), @spec.deploy_steps
  end

  test '#deploy_steps returns `cap $ENVIRONMENT deploy` if a `Capfile` is present' do
    @spec.expects(:bundler?).returns(true)
    @spec.expects(:capistrano?).returns(true)
    assert_equal ['bundle exec cap $ENVIRONMENT deploy'], @spec.deploy_steps
  end

  test '#deploy_steps raise a DeploySpec::Error! if it dont know how to deploy the app' do
    @spec.expects(:capistrano?).returns(false)
    assert_raise DeploySpec::Error do
      @spec.deploy_steps!
    end
  end

  test '#rollback_steps returns `rollback.override` if present' do
    @spec.stubs(:load_config).returns('rollback' => {'override' => %w(foo bar baz)})
    assert_equal %w(foo bar baz), @spec.rollback_steps
  end

  test '#rollback_steps returns `cap $ENVIRONMENT deploy:rollback` if a `Capfile` is present' do
    @spec.expects(:bundler?).returns(true)
    @spec.expects(:capistrano?).returns(true)
    assert_equal ['bundle exec cap $ENVIRONMENT deploy:rollback'], @spec.rollback_steps
  end

  test '#machine_env return an environment hash' do
    @spec.stubs(:load_config).returns('machine' => {'environment' => {'GLOBAL' => '1'}})
    assert_equal({'GLOBAL' => '1'}, @spec.machine_env)
  end

  test '#load_config can grab the env-specific shipit.yml file' do
    config = {}
    config.expects(:exist?).returns(true)
    config.expects(:read).returns({'dependencies' => {'override' => %w(foo bar baz)}}.to_yaml)
    spec = DeploySpec::FileSystem.new('.', 'staging')
    spec.expects(:file).with('shipit.staging.yml').returns(config)
    assert_equal %w(foo bar baz), spec.dependencies_steps
  end

  test '#load_config grabs the global shipit.yml file if there is no env-specific file' do
    not_config = {}
    not_config.expects(:exist?).returns(false)

    config = {}
    config.expects(:exist?).returns(true)
    config.expects(:read).returns({'dependencies' => {'override' => %w(foo bar baz)}}.to_yaml)

    spec = DeploySpec::FileSystem.new('.', 'staging')
    spec.expects(:file).with('shipit.staging.yml').returns(not_config)
    spec.expects(:file).with('shipit.yml').returns(config)
    assert_equal %w(foo bar baz), spec.dependencies_steps
  end

  test '#gemspec gives the path of the repo gemspec if present' do
    spec = DeploySpec::FileSystem.new('foobar/', 'production')
    Dir.expects(:[]).with('foobar/*.gemspec').returns(['foobar/foobar.gemspec'])
    assert_equal 'foobar/foobar.gemspec', spec.gemspec
  end

  test '#gem? is true if a gemspec is present' do
    @spec.expects(:gemspec).returns('something')
    assert @spec.gem?
  end

  test '#gem? is false if there is no gemspec' do
    @spec.expects(:gemspec).returns(nil)
    refute @spec.gem?
  end

  test '#publish_gem first check if version tag have been created, and then invoke bundler release task' do
    @spec.stubs(:gemspec).returns('/tmp/shipit.gemspec')
    refute @spec.capistrano?
    assert_equal ['assert-gem-version-tag /tmp/shipit.gemspec', 'bundle exec rake release'], @spec.deploy_steps
  end

  test '#cacheable returns a DeploySpec instance that can be serialized' do
    assert_instance_of DeploySpec::FileSystem, @spec
    assert_instance_of DeploySpec, @spec.cacheable
    config = {
      'machine' => {'environment' => {}},
      'dependencies' => {'override' => []},
      'deploy' => {'override' => nil},
      'rollback' => {'override' => nil},
      'fetch' => nil,
      'tasks' => {},
    }
    assert_equal config, @spec.cacheable.config
  end

  test "task definitions prepend bundle exec if necessary" do
    @spec.expects(:load_config).returns('tasks' => {'restart' => {'steps' => %w(foo)}})
    @spec.expects(:bundler?).returns(true).at_least_once
    definition = @spec.find_task_definition('restart')

    assert_equal ['bundle exec foo'], definition.steps
  end

  test "task definitions prepend bundle exec before serialization" do
    @spec.expects(:load_config).returns('tasks' => {'restart' => {'steps' => %w(foo)}})
    @spec.expects(:bundler?).returns(true).at_least_once

    cached_spec = DeploySpec.load(DeploySpec.dump(@spec))
    definition = cached_spec.find_task_definition('restart')
    assert_equal ['bundle exec foo'], definition.steps
  end

  test "#review_checklist returns an array" do
    @spec.expects(:load_config).returns('review' => {'checklist' => %w(foo bar)})
    assert_equal %w(foo bar), @spec.review_checklist
  end

  test "#review_checklist returns an empty array if the section is missing" do
    assert_equal [], @spec.review_checklist
  end
end
