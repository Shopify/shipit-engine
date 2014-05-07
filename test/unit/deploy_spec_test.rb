require 'test_helper'

class DeploySpecTest < ActiveSupport::TestCase

  setup do
    @spec = DeploySpec.new('.', 'staging')
    @spec.stubs(:load_config).returns({})
  end

  test '#dependencies_steps returns `dependencies.override` if present' do
    @spec.stubs(:load_config).returns('dependencies' => {'override' => %w(foo bar baz)})
    assert_equal %w(foo bar baz), @spec.dependencies_steps
  end

  test '#dependencies_steps returns env-specific `dependencies.override` if present' do
    @spec.stubs(:load_config).returns({
      'dependencies' => {'override' => %w(foo bar baz)},
      'staging' => {'dependencies' => {'override' => %w(bee baa boo)}}
    })
    assert_equal %w(bee baa boo), @spec.dependencies_steps
  end

  test '#dependencies_steps returns `dependencies.override` if env-specific is not present' do
    @spec.stubs(:load_config).returns({
      'dependencies' => {'override' => %w(foo bar baz)},
      'nonexistant' => {'dependencies' => {'override' => %w(bee baa boo)}}
    })
    assert_equal %w(foo bar baz), @spec.dependencies_steps
  end

  test '#dependencies_steps returns `bundle install` if a `Gemfile` is present' do
    @spec.expects(:bundler?).returns(true)
    @spec.expects(:bundle_install).returns(:bundle_install)
    assert_equal :bundle_install, @spec.dependencies_steps
  end

  test '#bundle_install return a sane default bundle install command' do
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

  test '#deploy_steps returns `deploy.override` if present' do
    @spec.stubs(:load_config).returns('deploy' => {'override' => %w(foo bar baz)})
    assert_equal %w(foo bar baz), @spec.deploy_steps
  end

  test '#deploy_steps returns env-specific `deploy.override` if present' do
    @spec.stubs(:load_config).returns({
      'deploy' => {'override' => %w(foo bar baz)},
      'staging' => {'deploy' => {'override' => %w(bee baa boo)}}
    })
    assert_equal %w(bee baa boo), @spec.deploy_steps
  end

  test '#deploy_steps returns `deploy.override` if env-specific is not present' do
    @spec.stubs(:load_config).returns({
      'deploy' => {'override' => %w(foo bar baz)},
      'nonexistant' => {'deploy' => {'override' => %w(bee baa boo)}}
    })
    assert_equal %w(foo bar baz), @spec.deploy_steps
  end

  test '#deploy_steps returns `cap $ENVIRONMENT deploy` if a `Capfile` is present' do
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

  test '#machine_env return an env-specific environment hash if present' do
    @spec.stubs(:load_config).returns({
      'machine' => {'environment' => {'GLOBAL' => '1'}},
      'staging' => {'machine' => {'environment' => {'GLOBAL' => '2'}}}
    })
    assert_equal({'GLOBAL' => '2'}, @spec.machine_env)
  end

  test '#machine_env return a global environment hash env-specific hash is not if present' do
    @spec.stubs(:load_config).returns({
      'machine' => {'environment' => {'GLOBAL' => '1'}},
      'nonexistant' => {'machine' => {'environment' => {'GLOBAL' => '2'}}}
    })
    assert_equal({'GLOBAL' => '1'}, @spec.machine_env)
  end

end
