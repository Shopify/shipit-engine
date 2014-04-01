require 'test_helper'

class DeploySpecTest < ActiveSupport::TestCase

  setup do
    @spec = DeploySpec.new('.')
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

  test '#deploy_steps returns `cap $ENVIRONMENT deploy` if a `Capfile` is present' do
    @spec.expects(:capistrano?).returns(true)
    assert_equal ['bundle exec cap $ENVIRONMENT deploy'], @spec.deploy_steps
  end

  test '#deploy_steps prepend `deploy.pre`' do
    @spec.stubs(:load_config).returns('deploy' => {'pre' => %w(foo bar baz)})
    assert_equal ['foo', 'bar', 'baz', 'bundle exec cap $ENVIRONMENT deploy'], @spec.deploy_steps
  end

  test '#deploy_steps append `deploy.post`' do
    @spec.stubs(:load_config).returns('deploy' => {'post' => %w(foo bar baz)})
    assert_equal ['bundle exec cap $ENVIRONMENT deploy', 'foo', 'bar', 'baz'], @spec.deploy_steps
  end

  test '#failure_steps returns `failure`' do
    @spec.stubs(:load_config).returns('failure' => %w(foo bar baz))
    assert_equal %w(foo bar baz), @spec.failure_steps
  end

  test '#success_steps returns `success`' do
    @spec.stubs(:load_config).returns('success' => %w(foo bar baz))
    assert_equal %w(foo bar baz), @spec.success_steps
  end

end
