require 'test_helper'

class DeploySpecTest < ActiveSupport::TestCase

  setup do
    @spec = DeploySpec.new('/tmp/', 'env')
    @spec.stubs(:load_config).returns({})
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

  test '#bundle_install return a sane default bundle install command' do
    @spec.stubs(:has_gemfile_lock?).returns(true)
    command = %Q(
      bundle check --path=#{DeploySpec::BUNDLE_PATH} ||
      bundle install
      --frozen
      --path=#{DeploySpec::BUNDLE_PATH}
      --retry=2
      --without=default:production:development:test:staging:benchmark:debug
    ).gsub(/\s+/, ' ').strip
    assert_equal command, @spec.bundle_install.first
  end

  test '#bundle_install use `dependencies.bundler.without` if present to build the --without argument' do
    @spec.stubs(:has_gemfile_lock?).returns(true)
    @spec.stubs(:load_config).returns('dependencies' => {'bundler' => {'without' => %w(some custom groups)}})
    command = %Q(
      bundle check --path=#{DeploySpec::BUNDLE_PATH} ||
      bundle install
      --frozen
      --path=#{DeploySpec::BUNDLE_PATH}
      --retry=2
      --without=some:custom:groups
    ).gsub(/\s+/, ' ').strip
    assert_equal command, @spec.bundle_install.first
  end

  test '#bundle_install has --frozen option if Gemfile.lock is present' do
    @spec.stubs(:load_config).returns('dependencies' => {'bundler' => {'without' => %w(some custom groups)}})
    @spec.stubs(:has_gemfile_lock?).returns(true)
    assert @spec.bundle_install.first.include?('--frozen')
  end

  test '#bundle_install does not have --frozen option if Gemfile.lock is not present' do
    @spec.stubs(:load_config).returns('dependencies' => {'bundler' => {'without' => %w(some custom groups)}})
    @spec.stubs(:has_gemfile_lock?).returns(false)
    refute @spec.bundle_install.first.include?('--frozen')
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

  test '#deploy_steps raise a DeploySpec::Error if it dont know how to deploy the app' do
    @spec.expects(:capistrano?).returns(false)
    assert_raise DeploySpec::Error do
      @spec.deploy_steps
    end
  end

  test '#machine_env return an environment hash' do
    @spec.stubs(:load_config).returns('machine' => {'environment' => {'GLOBAL' => '1'}})
    assert_equal({'GLOBAL' => '1'}, @spec.machine_env)
  end

  test '#load_config can grab the env-specific shipit.yml file' do
    config = {}
    config.expects(:exist?).returns(true)
    config.expects(:read).returns({'dependencies' => {'override' => %w(foo bar baz)}}.to_yaml)
    spec = DeploySpec.new('.', 'staging')
    spec.expects(:shipit_env_yml).twice.returns(config)
    assert_equal %w(foo bar baz), spec.dependencies_steps
  end

  test '#load_config grabs the global shipit.yml file if there is no env-specific file' do
    not_config = {}
    not_config.expects(:exist?).returns(false)

    config = {}
    config.expects(:exist?).returns(true)
    config.expects(:read).returns({'dependencies' => {'override' => %w(foo bar baz)}}.to_yaml)

    spec = DeploySpec.new('.', 'staging')
    spec.expects(:shipit_env_yml).once.returns(not_config)
    spec.expects(:shipit_yml).twice.returns(config)
    assert_equal %w(foo bar baz), spec.dependencies_steps
  end

  test '#gemspec gives the path of the repo gemspec if present' do
    spec = DeploySpec.new('foobar/', 'production')
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

end
