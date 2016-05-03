require 'test_helper'

module Shipit
  class DeploySpecTest < ActiveSupport::TestCase
    setup do
      @app_dir = '/tmp/'
      @spec = DeploySpec::FileSystem.new(@app_dir, 'env')
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
      @spec.expects(:bundle_install).returns(['bundle install'])
      assert_equal ['bundle install'], @spec.dependencies_steps
    end

    test "#dependencies_steps prepend and append pre and post steps" do
      @spec.stubs(:load_config).returns('dependencies' => {'pre' => ['before'], 'post' => ['after']})
      @spec.expects(:bundler?).returns(true)
      @spec.expects(:bundle_install).returns(['bundle install'])
      assert_equal ['before', 'bundle install', 'after'], @spec.dependencies_steps
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
      @spec.stubs(:gemfile_lock_exists?).returns(true)
      command = %(
        bundle check --path=#{DeploySpec.bundle_path} ||
        bundle install
        --frozen
        --path=#{DeploySpec.bundle_path}
        --retry=2
        --without=default:production:development:test:staging:benchmark:debug
      ).gsub(/\s+/, ' ').strip
      assert_equal command, @spec.bundle_install.last
    end

    test '#bundle_install use `dependencies.bundler.without` if present to build the --without argument' do
      @spec.stubs(:gemfile_lock_exists?).returns(true)
      @spec.stubs(:load_config).returns('dependencies' => {'bundler' => {'without' => %w(some custom groups)}})
      command = %(
        bundle check --path=#{DeploySpec.bundle_path} ||
        bundle install
        --frozen
        --path=#{DeploySpec.bundle_path}
        --retry=2
        --without=some:custom:groups
      ).gsub(/\s+/, ' ').strip
      assert_equal command, @spec.bundle_install.last
    end

    test '#bundle_install has --frozen option if Gemfile.lock is present' do
      @spec.stubs(:load_config).returns('dependencies' => {'bundler' => {'without' => %w(some custom groups)}})
      @spec.stubs(:gemfile_lock_exists?).returns(true)
      assert @spec.bundle_install.last.include?('--frozen')
    end

    test '#bundle_install does not have --frozen option if Gemfile.lock is not present' do
      @spec.stubs(:load_config).returns('dependencies' => {'bundler' => {'without' => %w(some custom groups)}})
      @spec.stubs(:gemfile_lock_exists?).returns(false)
      refute @spec.bundle_install.last.include?('--frozen')
    end

    test '#bundle_install does not have --frozen if overridden in shipit.yml' do
      @spec.stubs(:load_config).returns('dependencies' => {'bundler' => {'frozen' => false}})
      @spec.stubs(:gemfile_lock_exists?).returns(true)
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

    test "#deploy_steps prepend and append pre and post steps" do
      @spec.stubs(:load_config).returns('deploy' => {'pre' => ['before'], 'post' => ['after']})
      @spec.expects(:bundler?).returns(true)
      @spec.expects(:capistrano?).returns(true)
      assert_equal ['before', 'bundle exec cap $ENVIRONMENT deploy', 'after'], @spec.deploy_steps
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

    test "#rollback_steps prepend and append pre and post steps" do
      @spec.stubs(:load_config).returns('rollback' => {'pre' => ['before'], 'post' => ['after']})
      @spec.expects(:bundler?).returns(true)
      @spec.expects(:capistrano?).returns(true)
      assert_equal ['before', 'bundle exec cap $ENVIRONMENT deploy:rollback', 'after'], @spec.rollback_steps
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
      spec.expects(:file).with('shipit.staging.yml', root: true).returns(config)
      assert_equal %w(foo bar baz), spec.dependencies_steps
    end

    test '#load_config grabs the global shipit.yml file if there is no env-specific file' do
      not_config = {}
      not_config.expects(:exist?).returns(false)

      config = {}
      config.expects(:exist?).returns(true)
      config.expects(:read).returns({'dependencies' => {'override' => %w(foo bar baz)}}.to_yaml)

      spec = DeploySpec::FileSystem.new('.', 'staging')
      spec.expects(:file).with('shipit.staging.yml', root: true).returns(not_config)
      spec.expects(:file).with('shipit.yml', root: true).returns(config)
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

    test '#setup_dot_py gives the path of the repo setup.py if present' do
      spec = DeploySpec::FileSystem.new('foobar/', 'production')
      assert_equal Pathname.new('foobar/setup.py'), spec.setup_dot_py
    end

    test '#egg? is true if a setup.py is present' do
      @spec.expects(:setup_dot_py).returns(Shipit::Engine.root.join('Gemfile'))
      assert @spec.egg?
    end

    test '#egg? is false if there is no setup.py' do
      @spec.expects(:setup_dot_py).returns(Shipit::Engine.root.join("tmp-#{SecureRandom.hex}"))
      refute @spec.egg?
    end

    test '#publish_egg first check if version tag have been created and then invoke setup.py upload' do
      file = Pathname.new('/tmp/fake_setup.py')
      file.write('foo')
      @spec.stubs(:setup_dot_py).returns(file)
      steps = ['assert-egg-version-tag /tmp/fake_setup.py', 'python setup.py register sdist upload']
      assert_equal steps, @spec.deploy_steps
    end

    test '#cacheable returns a DeploySpec instance that can be serialized' do
      assert_instance_of DeploySpec::FileSystem, @spec
      assert_instance_of DeploySpec, @spec.cacheable
      config = {
        'ci' => {'hide' => [], 'allow_failures' => [], 'require' => []},
        'machine' => {'environment' => {}, 'directory' => nil, 'cleanup' => true},
        'review' => {'checklist' => [], 'monitoring' => [], 'checks' => []},
        'dependencies' => {'override' => []},
        'plugins' => {},
        'deploy' => {'override' => nil, 'variables' => [], 'max_commits' => nil},
        'rollback' => {'override' => nil},
        'fetch' => nil,
        'tasks' => {},
      }
      assert_equal config, @spec.cacheable.config
    end

    test "#deploy_variables returns an empty array by default" do
      assert_equal [], @spec.deploy_variables
    end

    test "#deploy_variables returns an array of VariableDefinition instances" do
      @spec.stubs(:load_config).returns('deploy' => {'variables' => [{
        'name' => 'SAFETY_DISABLED',
        'title' => 'Set to 1 to do dangerous things',
        'default' => 0,
      }]})

      assert_equal 1, @spec.deploy_variables.size
      variable_definition = @spec.deploy_variables.first
      assert_equal 'SAFETY_DISABLED', variable_definition.name
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

    test "task definitions returns an array of VariableDefinition instances" do
      @spec.expects(:load_config).returns('tasks' =>
        {'restart' =>
          {
            'variables' => [
              {
                'name' => 'SAFETY_DISABLED',
                'title' => 'Set to 1 to do dangerous things',
                'default' => 0,
              },
              {
                'name' => 'FOO',
                'title' => 'Set to 0 to foo',
                'default' => 1,
              },
            ],
            'steps' => %w(foo),
          },
        })

      assert_equal 2, @spec.task_definitions.first.variables.size
      variable_definition = @spec.task_definitions.first.variables.first
      assert_equal 'SAFETY_DISABLED', variable_definition.name
    end

    test "task definitions returns an empty array by default" do
      assert_equal [], @spec.task_definitions
    end

    test "#review_checklist returns an array" do
      @spec.expects(:load_config).returns('review' => {'checklist' => %w(foo bar)})
      assert_equal %w(foo bar), @spec.review_checklist
    end

    test "#review_checklist returns an empty array if the section is missing" do
      assert_equal [], @spec.review_checklist
    end

    test "#review_monitoring returns an array of hashes" do
      @spec.expects(:load_config).returns('review' => {'monitoring' => [
        {'image' => 'http://example.com/foo.png', 'width' => 200, 'height' => 400},
        {'iframe' => 'http://example.com/', 'width' => 200, 'height' => 400},
      ]})
      assert_equal [
        {'image' => 'http://example.com/foo.png', 'width' => 200, 'height' => 400},
        {'iframe' => 'http://example.com/', 'width' => 200, 'height' => 400},
      ], @spec.review_monitoring
    end

    test "#review_monitoring returns an empty array if the section is missing" do
      assert_equal [], @spec.review_monitoring
    end

    test "#hidden_statuses is empty by default" do
      assert_equal [], @spec.hidden_statuses
    end

    test "#hidden_statuses is an array even if the value is a string" do
      @spec.expects(:load_config).returns('ci' => {'hide' => 'ci/circleci'})
      assert_equal %w(ci/circleci), @spec.hidden_statuses
    end

    test "#hidden_statuses is an array even if the value is present" do
      @spec.expects(:load_config).returns('ci' => {'hide' => %w(ci/circleci ci/jenkins)})
      assert_equal %w(ci/circleci ci/jenkins), @spec.hidden_statuses
    end

    test "#file is impacted by `machine.directory`" do
      subdir = '/foo/bar'
      @spec.stubs(:load_config).returns('machine' => {'directory' => subdir})
      assert_instance_of Pathname, @spec.file('baz')
      assert_equal File.join(@app_dir, subdir, 'baz'), @spec.file('baz').to_s
    end

    test "#clear_working_directory? returns true by default" do
      assert_predicate @spec, :clear_working_directory?
    end
  end
end
