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
      @spec.expects(:bundler?).returns(true).at_least_once
      @spec.expects(:bundle_install).returns(['bundle install'])
      assert_equal ['bundle install'], @spec.dependencies_steps
    end

    test "#dependencies_steps prepend and append pre and post steps" do
      @spec.stubs(:load_config).returns('dependencies' => {'pre' => ['before'], 'post' => ['after']})
      @spec.expects(:bundler?).returns(true).at_least_once
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
        bundle install
        --frozen
        --jobs 4
        --path #{DeploySpec.bundle_path}
        --retry 2
        --without=default:production:development:test:staging:benchmark:debug
      ).gsub(/\s+/, ' ').strip
      assert_equal command, @spec.bundle_install.last
    end

    test '#bundle_install use `dependencies.bundler.without` if present to build the --without argument' do
      @spec.stubs(:gemfile_lock_exists?).returns(true)
      @spec.stubs(:load_config).returns('dependencies' => {'bundler' => {'without' => %w(some custom groups)}})
      command = %(
        bundle install
        --frozen
        --jobs 4
        --path #{DeploySpec.bundle_path}
        --retry 2
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
      @spec.expects(:bundler?).returns(true).at_least_once
      @spec.expects(:capistrano?).returns(true)
      assert_equal ['bundle exec cap $ENVIRONMENT deploy'], @spec.deploy_steps
    end

    test "#deploy_steps returns `kubernetes-deploy <namespace> <context>` if `kubernetes` is present" do
      @spec.stubs(:load_config).returns(
        'kubernetes' => {
          'namespace' => 'foo',
          'context' => 'bar',
        },
      )
      assert_equal ["kubernetes-deploy --max-watch-seconds 900 foo bar"], @spec.deploy_steps
    end

    test "#deploy_steps `kubernetes` respects timeout false" do
      @spec.stubs(:load_config).returns(
        'kubernetes' => {
          'namespace' => 'foo',
          'context' => 'bar',
          'timeout' => false,
        },
      )
      assert_equal ["kubernetes-deploy foo bar"], @spec.deploy_steps
    end

    test "#deploy_steps returns kubernetes-deploy command if both capfile and `kubernetes` are present" do
      @spec.stubs(:bundler?).returns(true)
      @spec.stubs(:capistrano?).returns(true)
      @spec.stubs(:load_config).returns(
        'kubernetes' => {
          'namespace' => 'foo',
          'context' => 'bar',
        },
      )
      assert_equal ["kubernetes-deploy --max-watch-seconds 900 foo bar"], @spec.deploy_steps
    end

    test "#deploy_steps returns kubernetes command if `kubernetes` is present and template_dir is set" do
      @spec.stubs(:load_config).returns(
        'kubernetes' => {
          'namespace' => 'foo',
          'context' => 'bar',
          'template_dir' => 'k8s_templates/',
        },
      )
      assert_equal ["kubernetes-deploy --max-watch-seconds 900 --template-dir k8s_templates/ foo bar"], @spec.deploy_steps
    end

    test "#deploy_steps prepend and append pre and post steps" do
      @spec.stubs(:load_config).returns('deploy' => {'pre' => ['before'], 'post' => ['after']})
      @spec.expects(:bundler?).returns(true).at_least_once
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
      @spec.expects(:bundler?).returns(true).at_least_once
      @spec.expects(:capistrano?).returns(true)
      assert_equal ['bundle exec cap $ENVIRONMENT deploy:rollback'], @spec.rollback_steps
    end

    test "#rollback_steps prepend and append pre and post steps" do
      @spec.stubs(:load_config).returns('rollback' => {'pre' => ['before'], 'post' => ['after']})
      @spec.expects(:bundler?).returns(true).at_least_once
      @spec.expects(:capistrano?).returns(true)
      assert_equal ['before', 'bundle exec cap $ENVIRONMENT deploy:rollback', 'after'], @spec.rollback_steps
    end

    test "#rollback_steps returns `kubernetes-deploy <namespace> <context>` if `kubernetes` is present" do
      @spec.stubs(:load_config).returns(
        'kubernetes' => {
          'namespace' => 'foo',
          'context' => 'bar',
        },
      )
      assert_equal ["kubernetes-deploy --max-watch-seconds 900 foo bar"], @spec.rollback_steps
    end

    test "#rollback_steps returns kubernetes-deploy command when both capfile and `kubernetes` are present" do
      @spec.stubs(:bundler?).returns(true)
      @spec.stubs(:capistrano?).returns(true)
      @spec.stubs(:load_config).returns(
        'kubernetes' => {
          'namespace' => 'foo',
          'context' => 'bar',
        },
      )
      assert_equal ["kubernetes-deploy --max-watch-seconds 900 foo bar"], @spec.rollback_steps
    end

    test "#discover_task_definitions include a kubernetes restart command if `kubernetes` is present" do
      @spec.stubs(:load_config).returns(
        'kubernetes' => {
          'namespace' => 'foo',
          'context' => 'bar',
        },
      )
      tasks = {
        'restart' => {
          'action' => 'Restart application',
          'description' => 'Simulates a rollout of Kubernetes deployments by using kubernetes-restart utility',
          'steps' => ['kubernetes-restart foo bar --max-watch-seconds 900'],
        },
      }
      assert_equal tasks, @spec.discover_task_definitions
    end

    test "#discover_task_definitions include the user defined restart command even if `kubernetes` is present" do
      tasks = {
        'restart' => {
          'action' => 'Restart application',
          'description' => 'Simulates a rollout of Kubernetes deployments by using kubernetes-restart utility',
          'steps' => ['kubernetes-restart something custom'],
        },
        'some-other-tasj' => {
          'action' => 'Do something else',
          'description' => 'Eat some chips!',
          'steps' => ['echo chips'],
        },
      }
      @spec.stubs(:load_config).returns(
        'kubernetes' => {
          'namespace' => 'foo',
          'context' => 'bar',
        },
        'tasks' => tasks,
      )
      assert_equal tasks, @spec.discover_task_definitions
    end

    test '#machine_env returns an environment hash' do
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
      assert_equal ['release-gem /tmp/shipit.gemspec'], @spec.deploy_steps
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
      steps = [
        'assert-egg-version-tag /tmp/fake_setup.py',
        'python setup.py register sdist',
        'twine upload dist/*',
      ]
      assert_equal steps, @spec.deploy_steps
    end

    test '#cacheable returns a DeploySpec instance that can be serialized' do
      assert_instance_of DeploySpec::FileSystem, @spec
      assert_instance_of DeploySpec, @spec.cacheable
      config = {
        'merge' => {
          'require' => [],
          'ignore' => [],
          'revalidate_after' => nil,
          'method' => nil,
          'max_divergence' => {
            'commits' => nil,
            'age' => nil,
          },
        },
        'ci' => {
          'hide' => [],
          'allow_failures' => [],
          'require' => [],
          'blocking' => [],
        },
        'machine' => {
          'environment' => {'BUNDLE_PATH' => @spec.bundle_path.to_s},
          'directory' => nil,
          'cleanup' => true,
        },
        'review' => {'checklist' => [], 'monitoring' => [], 'checks' => []},
        'status' => {
          'context' => nil,
          'delay' => 0,
        },
        'dependencies' => {'override' => []},
        'plugins' => {},
        'deploy' => {
          'override' => nil,
          'variables' => [],
          'max_commits' => 8,
          'interval' => 0,
        },
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

    test "task definitions don't prepend bundle exec by default" do
      @spec.expects(:load_config).returns('tasks' => {'restart' => {'steps' => %w(foo)}})
      definition = @spec.find_task_definition('restart')
      assert_equal ['foo'], definition.steps
    end

    test "task definitions don't bundle exec before serialization" do
      @spec.expects(:discover_task_definitions).returns('restart' => {'steps' => %w(foo)})
      @spec.expects(:bundler?).returns(true).at_least_once

      cached_spec = DeploySpec.load(DeploySpec.dump(@spec))
      definition = cached_spec.find_task_definition('restart')
      assert_equal ['foo'], definition.steps
    end

    test "#task_definitions will always have definitions from shipit.yml take precedence over other modules" do
      # Create a subclass of `FileSystem` which we can include another module in without
      # affecting any other tests
      DuplicateCustomizedDeploySpec = Class.new(Shipit::DeploySpec::FileSystem)

      # Create the module we want to include in our new class
      # For this test case, we want to have the module create a task with the same
      # ID as defined from config
      module TestTaskDiscovery
        def discover_task_definitions
          {
            'config_task' => {'steps' => %w(bar)},
          }.merge!(super)
        end
      end

      # Include the module in our new test class
      DuplicateCustomizedDeploySpec.include TestTaskDiscovery

      # Setup the spec as we would normally, but use the customized version
      @spec = DuplicateCustomizedDeploySpec.new(@app_dir, 'env')
      @spec.stubs(:load_config).returns(
        'tasks' => {'config_task' => {'steps' => %w(foo)}},
      )
      tasks = @spec.task_definitions

      # Assert we get only the task from the config, not from the module
      assert_equal %w(config_task), tasks.map(&:id)
      assert_equal ["foo"], tasks.first.steps
    end

    test "#task_definitions returns comands from the config and other modules" do
      # Create a subclass of `FileSystem` which we can include another module in without
      # affecting any other tests
      CustomizedDeploySpec = Class.new(Shipit::DeploySpec::FileSystem)

      # Create the module we want to include in our new class
      # This module demonstrates how to have new tasks to be appended to the task list
      module TestTaskDiscovery
        def discover_task_definitions
          {
            'module_task' => {'steps' => %w(bar)},
          }.merge(super)
        end
      end

      # Include the module in our new test class
      CustomizedDeploySpec.include TestTaskDiscovery

      # Setup the spec as we would normally, but use the customized version
      @spec = CustomizedDeploySpec.new(@app_dir, 'env')
      @spec.stubs(:load_config).returns(
        'tasks' => {'config_task' => {'steps' => %w(foo)}},
        'kubernetes' => {
          'namespace' => 'foo',
          'context' => 'bar',
          'timeout' => '20m',
        },
      )
      tasks = @spec.task_definitions

      # Assert we get tasks from all three sources: config, shipit-engine defined modules, and
      # "third party" modules
      assert_equal %w(config_task module_task restart), tasks.map(&:id).sort

      module_task = tasks.find { |t| t.id == "config_task" }
      assert_equal ["foo"], module_task.steps

      config_task = tasks.find { |t| t.id == "module_task" }
      assert_equal ["bar"], config_task.steps

      restart_task = tasks.find { |t| t.id == "restart" }
      assert_equal ["kubernetes-restart foo bar --max-watch-seconds 1200"], restart_task.steps
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

    test "#required_statuses automatically includes #blocking_statuses" do
      @spec.expects(:load_config).returns(
        'ci' => {
          'require' => %w(ci/circleci),
          'blocking' => %w(soc/compliance),
        },
      )
      assert_equal %w(ci/circleci soc/compliance), @spec.required_statuses
    end

    test "pull_request_merge_method defaults to `nil`" do
      @spec.expects(:load_config).returns({})
      assert_nil @spec.pull_request_merge_method
    end

    test "pull_request_merge_method returns `merge.method`" do
      @spec.expects(:load_config).returns(
        'merge' => {
          'method' => 'squash',
        },
      )
      assert_equal 'squash', @spec.pull_request_merge_method
    end

    test "pull_request_merge_method returns `nil` if `merge.method` is invalid" do
      @spec.expects(:load_config).returns(
        'merge' => {
          'method' => 'squashing',
        },
      )
      assert_nil @spec.pull_request_merge_method
    end

    test "pull_request_ignored_statuses defaults to the union of ci.hide and ci.allow_failures" do
      @spec.expects(:load_config).returns(
        'ci' => {
          'hide' => %w(ci/circleci ci/jenkins),
          'allow_failures' => %w(ci/circleci ci/travis),
        },
      )
      assert_equal %w(ci/circleci ci/jenkins ci/travis).sort, @spec.pull_request_ignored_statuses.sort
    end

    test "pull_request_ignored_statuses defaults to empty if `merge.require` is present" do
      @spec.expects(:load_config).returns(
        'merge' => {
          'require' => 'bar',
        },
        'ci' => {
          'hide' => %w(ci/circleci ci/jenkins),
          'allow_failures' => %w(ci/circleci ci/travis),
        },
      )
      assert_equal [], @spec.pull_request_ignored_statuses
    end

    test "pull_request_ignored_statuses returns `merge.ignore` if present" do
      @spec.expects(:load_config).returns(
        'merge' => {
          'ignore' => 'bar',
        },
        'ci' => {
          'hide' => %w(ci/circleci ci/jenkins),
          'allow_failures' => %w(ci/circleci ci/travis),
        },
      )
      assert_equal ['bar'], @spec.pull_request_ignored_statuses
    end

    test "pull_request_required_statuses defaults to ci.require" do
      @spec.expects(:load_config).returns(
        'ci' => {
          'require' => %w(ci/circleci ci/jenkins),
        },
      )
      assert_equal %w(ci/circleci ci/jenkins), @spec.pull_request_required_statuses
    end

    test "pull_request_required_statuses defaults to empty if `merge.ignore` is present" do
      @spec.expects(:load_config).returns(
        'merge' => {
          'ignore' => 'bar',
        },
        'ci' => {
          'require' => %w(ci/circleci ci/jenkins),
        },
      )
      assert_equal [], @spec.pull_request_required_statuses
    end

    test "pull_request_required_statuses returns `merge.require` if present" do
      @spec.expects(:load_config).returns(
        'merge' => {
          'require' => 'bar',
        },
        'ci' => {
          'hide' => %w(ci/circleci ci/jenkins),
          'allow_failures' => %w(ci/circleci ci/travis),
        },
      )
      assert_equal ['bar'], @spec.pull_request_required_statuses
    end

    test "revalidate_pull_requests_after defaults to `nil" do
      @spec.expects(:load_config).returns({})
      assert_nil @spec.revalidate_pull_requests_after
    end

    test "revalidate_pull_requests_after defaults to `nil` if `merge.timeout` cannot be parsed" do
      @spec.expects(:load_config).returns(
        'merge' => {
          'revalidate_after' => 'ALSKhfjsdkf',
        },
      )
      assert_nil @spec.revalidate_pull_requests_after
    end

    test "revalidate_after returns `merge.revalidate_after` if present" do
      @spec.expects(:load_config).returns(
        'merge' => {
          'revalidate_after' => '5m30s',
        },
      )
      assert_equal 330, @spec.revalidate_pull_requests_after.to_i
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

    test 'bundler installs take priority over npm installs' do
      @spec.expects(:discover_package_json).never
      @spec.stubs(:discover_bundler).returns(['fake bundler task']).once

      assert_equal ['fake bundler task'], @spec.dependencies_steps
    end

    test 'Gems deploys take priority over npm deploys' do
      @spec.expects(:discover_npm_package).never
      @spec.stubs(:discover_gem).returns(['fake gem task']).once

      assert_equal ['fake gem task'], @spec.deploy_steps
    end

    test 'lerna monorepos take priority over solo npm deploys' do
      @spec.expects(:discover_npm_package).never
      @spec.stubs(:discover_lerna_packages).returns(['fake monorepo task']).once

      assert_equal ['fake monorepo task'], @spec.deploy_steps
    end

    test '#lerna? is false if there is no lerna.json' do
      @spec.expects(:lerna_json).returns(Shipit::Engine.root.join("tmp-#{SecureRandom.hex}"))
      refute @spec.lerna?
    end

    test '#npm? is false if there is no package.json' do
      @spec.expects(:package_json).returns(Shipit::Engine.root.join("tmp-#{SecureRandom.hex}"))
      refute @spec.npm?
    end

    test '#npm? is true if npm package is public' do
      file = Pathname.new('/tmp/fake_package.json')
      file.write('{"private": false}')

      @spec.expects(:package_json).returns(file)

      assert @spec.npm?
    end

    test '#npm? is false if npm package is private' do
      file = Pathname.new('/tmp/fake_package.json')
      file.write('{"private": true}')

      @spec.expects(:package_json).returns(file)
      refute @spec.npm?
    end

    test 'lerna monorepos have a checklist' do
      @spec.stubs(:lerna?).returns(true).at_least_once
      @spec.stubs(:lerna_config).returns('lerna' => '2.0.0', 'version' => '1.0.0')
      assert_match(/lerna publish --skip-npm/, @spec.review_checklist[0])
    end

    test 'npm packages have a checklist' do
      @spec.stubs(:npm?).returns(true).at_least_once
      assert_match(/npm version/, @spec.review_checklist[0])
    end

    test '#lerna_version returns the monorepo root version number' do
      file = Pathname.new('/tmp/fake_lerna.json')
      file.write('{"version": "1.0.0-beta.1"}')

      @spec.expects(:lerna_json).at_least_once.returns(file)
      assert_equal '1.0.0-beta.1', @spec.lerna_version
    end

    test '#lerna_lerna returns the lerna version specified' do
      file = Pathname.new('/tmp/fake_lerna.json')
      file.write('{"version": "1.0.0-beta.1", "lerna": "3.13.3"}')

      @spec.expects(:lerna_json).at_least_once.returns(file)
      assert_equal Gem::Version.new('3.13.3'), @spec.lerna_lerna
    end

    test '#package_version returns the version number' do
      file = Pathname.new('/tmp/fake_package.json')
      file.write('{"version": "1.0.0-beta.1"}')

      @spec.expects(:package_json).returns(file)
      assert_equal '1.0.0-beta.1', @spec.package_version
    end

    test '#dist_tag returns "latest" if the version does not contains a standard pre-release tag' do
      assert_equal 'latest', @spec.dist_tag('1.0.0')
      assert_equal 'latest', @spec.dist_tag('1.0.0-shopifyv4')
    end

    test '#dist_tag returns "next" if the version contains a pre-release tag' do
      assert_equal 'next', @spec.dist_tag('1.0.0-alpha.1')
      assert_equal 'next', @spec.dist_tag('1.0.0-beta')
      assert_equal 'next', @spec.dist_tag('1.0.0-rc.3')
      assert_equal 'next', @spec.dist_tag('1.0.0-next')
    end

    test '#dependencies_steps returns lerna setup if a `lerna.json` is present' do
      @spec.expects(:lerna?).returns(true).at_least_once
      assert_equal ['npm install --no-progress', 'node_modules/.bin/lerna bootstrap'], @spec.dependencies_steps
    end

    test '#dependencies_steps returns `npm install` if a `package.json` is present' do
      @spec.expects(:npm?).returns(true).at_least_once
      assert_equal ['npm install --no-progress'], @spec.dependencies_steps
    end

    test '#publish_lerna_packages checks if independent version tags exist, and then invokes lerna deploy script' do
      @spec.stubs(:lerna?).returns(true)
      @spec.stubs(:lerna_config).returns('lerna' => '2.0.0', 'version' => 'independent')
      assert_equal 'assert-lerna-independent-version-tags', @spec.deploy_steps[0]
      assert_equal 'publish-lerna-independent-packages', @spec.deploy_steps[1]
    end

    test '#publish_lerna_packages checks if fixed version tag exists, and then invokes lerna deploy script' do
      @spec.stubs(:lerna?).returns(true)
      @spec.stubs(:lerna_config).returns('lerna' => '2.0.0', 'version' => '1.0.0')
      assert_equal 'assert-lerna-fixed-version-tag', @spec.deploy_steps[0]
      assert_equal 'node_modules/.bin/lerna publish --yes --skip-git --repo-version 1.0.0 --force-publish=* --npm-tag latest --npm-client=npm --skip-npm=false', @spec.deploy_steps[1]
    end

    test '#publish_lerna_packages checks if a newer version of lerna is used, and will then use the new publish syntax, correctly setting the `latest` dist tag' do
      @spec.stubs(:lerna?).returns(true)
      @spec.stubs(:lerna_config).returns('lerna' => '3.0.0', 'version' => '1.0.0')
      assert_equal 'assert-lerna-fixed-version-tag', @spec.deploy_steps[0]
      assert_equal 'node_modules/.bin/lerna publish from-git --yes --dist-tag latest', @spec.deploy_steps[1]
    end

    test '#publish_lerna_packages checks if a newer version of lerna is used, and will then use the new publish syntax, correctly setting the `next` dist tag' do
      @spec.stubs(:lerna?).returns(true)
      @spec.stubs(:lerna_config).returns('lerna' => '3.0.0', 'version' => 'v1.3.1-alpha.2')
      assert_equal 'assert-lerna-fixed-version-tag', @spec.deploy_steps[0]
      assert_equal 'node_modules/.bin/lerna publish from-git --yes --dist-tag next', @spec.deploy_steps[1]
    end

    test '#enforce_publish_config? is false when Shipit.enforce_publish_config is nil' do
      Shipit.stubs(:enforce_publish_config).returns(nil)
      refute @spec.enforce_publish_config?
    end

    test '#enforce_publish_config? is false when Shipit.enforce_publish_config is 0' do
      Shipit.stubs(:enforce_publish_config).returns('0')
      refute @spec.enforce_publish_config?
    end

    test '#enforce_publish_config? is true when Shipit.enforce_publish_config is 1' do
      Shipit.stubs(:enforce_publish_config).returns('1')
      assert @spec.enforce_publish_config?
    end

    test '#valid_publish_config? is false when enforce_publish_config? is true and publishConfig is missing from package.json' do
      Shipit.stubs(:private_npm_registry).returns('some_private_registry')
      @spec.stubs(:enforce_publish_config?).returns(true)
      @spec.stubs(:publish_config_access).returns('restricted')

      package_json = Pathname.new('/tmp/fake_package.json')
      package_json.write('{"name": "foo"}')

      @spec.expects(:package_json).returns(package_json)
      refute @spec.valid_publish_config?
    end

    test '#valid_publish_config? is true when enforce_publish_config? is true and publishConfig.access is public' do
      Shipit.stubs(:private_npm_registry).returns('some_private_registry')
      @spec.stubs(:enforce_publish_config?).returns(true)
      @spec.stubs(:publish_config_access).returns('public')
      @spec.stubs(:publish_config).returns('something')

      assert @spec.valid_publish_config?
    end

    test '#valid_publish_config? is true when shipit does not enforce a publishConfig' do
      @spec.stubs(:lerna?).returns(true)
      @spec.stubs(:lerna_config).returns('lerna' => '2.0.0', 'version' => '1.0.0')
      assert @spec.valid_publish_config?
    end

    test '#publish_config returns publishConfig from package.json' do
      package_json = Pathname.new('/tmp/fake_package.json')
      package_json.write('{"publishConfig": "foo"}')

      @spec.expects(:package_json).returns(package_json)
      assert_equal "foo", @spec.publish_config
    end

    test '#valid_publish_config_access? is false when publishConfig.access is invalid' do
      @spec.stubs(:publish_config_access).returns('foo')
      refute @spec.valid_publish_config_access?
    end

    test '#valid_publish_config_access? is true when publishConfig.access is public or restricted' do
      @spec.stubs(:publish_config_access).returns('public')
      assert @spec.valid_publish_config_access?

      @spec.stubs(:publish_config_access).returns('restricted')
      assert @spec.valid_publish_config_access?
    end

    test '#publish_config_access is restricted when enforce_publish_config? is true and publishConfig is missing' do
      package_json = Pathname.new('/tmp/fake_package.json')
      package_json.write('{"name": "@shopify/foo"}')

      @spec.stubs(:enforce_publish_config?).returns(true)
      @spec.expects(:package_json).returns(package_json)
      assert_equal 'restricted', @spec.publish_config_access
    end

    test '#publish_config_access is public when enforce_publish_config? is false and publishConfig is missing' do
      package_json = Pathname.new('/tmp/fake_package.json')
      package_json.write('{"name": "@shopify/foo"}')

      @spec.stubs(:enforce_publish_config?).returns(false)
      @spec.expects(:package_json).returns(package_json)
      assert_equal 'public', @spec.publish_config_access
    end

    test '#publish_config_access returns publishConfig.access from package.json when enforce_publish_config? is true' do
      package_json = Pathname.new('/tmp/fake_package.json')
      package_json.write('{
        "name": "@shopify/foo",
        "publishConfig": {
          "access": "foo"
        }
      }')

      @spec.stubs(:enforce_publish_config?).returns(false)
      @spec.expects(:package_json).returns(package_json)
      assert_equal 'foo', @spec.publish_config_access
    end

    test "#scoped_package? is false when Shipit.npm_org_scope is not set and the package is private" do
      Shipit.stubs(:npm_org_scope).returns(nil)
      @spec.stubs(:publish_config_access).returns('restricted')
      refute @spec.scoped_package?
    end

    test "#scoped_package? is true when Shipit.npm_org_scope is set and package_name starts with scope and the package is private" do
      Shipit.stubs(:npm_org_scope).returns('@shopify')
      @spec.stubs(:publish_config_access).returns('restricted')
      @spec.stubs(:package_name).returns('@shopify/polaris')
      assert @spec.scoped_package?
    end

    test "#private_scoped_package? is false when private packages are not scoped" do
      @spec.stubs(:scoped_package?).returns(false)
      @spec.stubs(:publish_config_access).returns("restricted")
      refute @spec.private_scoped_package?
    end

    test "#private_scoped_package? is true when private packages are scoped" do
      @spec.stubs(:scoped_package?).returns(true)
      @spec.stubs(:publish_config_access).returns("restricted")
      assert @spec.private_scoped_package?
    end

    test '#publish_npm_package checks if version tag exists, and then invokes npm deploy script' do
      @spec.stubs(:npm?).returns(true)
      @spec.stubs(:package_version).returns('1.0.0')
      @spec.stubs(:valid_publish_config?).returns(true)
      @spec.stubs(:publish_config_access).returns('restricted')
      @spec.stubs(:registry).returns("@private:registry=some_private_registry")
      assert_equal ['assert-npm-version-tag', 'npm publish --tag latest --access restricted'], @spec.deploy_steps
    end

    test '#npmrc_contents returns a scoped private package configuration when the package is scoped and private' do
      registry = "@shopify:registry=some_private_registry"
      Shipit.stubs(:npm_org_scope).returns('@shopify')
      Shipit.stubs(:private_npm_registry).returns('some_private_registry')
      @spec.stubs(:scoped_package?).returns(true)
      @spec.stubs(:publish_config_access).returns('restricted')
      assert_equal registry, @spec.registry
    end

    test '#npmrc_contents returns a public scoped package configuration when the package is scoped and public' do
      registry = "@shopify:registry=https://registry.npmjs.org/"
      Shipit.stubs(:npm_org_scope).returns('@shopify')
      @spec.stubs(:scoped_package?).returns(true)
      @spec.stubs(:publish_config_access).returns('public')
      assert_equal registry, @spec.registry
    end

    test '#npmrc_contents returns a public non-scoped package configuration when the package is not scoped and public' do
      registry = "registry=https://registry.npmjs.org/"
      @spec.stubs(:scoped_package?).returns(false)
      @spec.stubs(:publish_config_access).returns('public')
      assert_equal registry, @spec.registry
    end

    test '#publish_lerna_packages guesses npm tag' do
      @spec.stubs(:lerna?).returns(true)
      @spec.stubs(:lerna_config).returns('lerna' => '2.0.0', 'version' => '1.0.0-alpha.1')
      assert_match(/--npm-tag next/, @spec.deploy_steps.last)
    end

    test '#publish_npm_package checks if version tag and a pre-release flag exist, and then invokes npm deploy script' do
      @spec.stubs(:npm?).returns(true)
      @spec.stubs(:package_version).returns('1.0.0-alpha.1')
      @spec.stubs(:valid_publish_config?).returns(true)
      @spec.stubs(:publish_config_access).returns('restricted')
      @spec.stubs(:registry).returns("@private:registry=some_private_registry")
      assert_equal ['assert-npm-version-tag', 'npm publish --tag next --access restricted'], @spec.deploy_steps
    end

    test 'bundler installs take priority over yarn installs' do
      @spec.expects(:discover_yarn).never
      @spec.stubs(:discover_bundler).returns(['fake bundler task']).once

      assert_equal ['fake bundler task'], @spec.dependencies_steps
    end

    test 'Gems deploys take priority over yarn deploys' do
      @spec.expects(:discover_yarn_package).never
      @spec.stubs(:discover_gem).returns(['fake gem task']).once

      assert_equal ['fake gem task'], @spec.deploy_steps
    end

    test '#yarn? is false if there is no package.json' do
      @spec.expects(:package_json).returns(Shipit::Engine.root.join("tmp-#{SecureRandom.hex}"))
      @spec.expects(:yarn_lock).returns(Shipit::Engine.root.join('Gemfile'))

      refute @spec.yarn?
    end

    test '#yarn? is false if there is no yarn.lock' do
      @spec.expects(:yarn_lock).returns(Shipit::Engine.root.join("tmp-#{SecureRandom.hex}"))

      refute @spec.yarn?
    end

    test '#yarn? is false if a private package.json and yarn.lock are present' do
      package_json = Pathname.new('/tmp/fake_package.json')
      package_json.write('{"private": true}')

      @spec.expects(:package_json).returns(package_json)
      @spec.expects(:yarn_lock).returns(Shipit::Engine.root.join('Gemfile'))
      refute @spec.yarn?
    end

    test '#yarn? is true if a public package.json and yarn.lock are present' do
      package_json = Pathname.new('/tmp/fake_package.json')
      package_json.write('{"private": false}')

      yarn_lock = Pathname.new('/tmp/fake_yarn.lock')
      yarn_lock.write('')

      @spec.expects(:package_json).returns(package_json)
      @spec.expects(:yarn_lock).returns(yarn_lock)
      assert @spec.yarn?
    end

    test '#dependencies_steps returns `yarn install` if a `yarn.lock` is present' do
      @spec.expects(:yarn?).returns(true).at_least_once
      assert_equal ['yarn install --no-progress'], @spec.dependencies_steps
    end

    test '#publish_npm_package checks if version tag exists, and then invokes npm publish script' do
      @spec.stubs(:yarn?).returns(true).at_least_once
      @spec.stubs(:package_version).returns('1.0.0')
      @spec.stubs(:valid_publish_config?).returns(true)
      @spec.stubs(:publish_config_access).returns('restricted')
      @spec.stubs(:registry).returns("@private:registry=some_private_registry")
      assert_equal ['assert-npm-version-tag', 'npm publish --tag latest --access restricted'], @spec.deploy_steps
    end

    test '#publish_npm_package checks if version tag exists, generates npmrc, and then invokes npm publish script when enforce_publish_config? is true' do
      @spec.stubs(:yarn?).returns(true).at_least_once
      @spec.stubs(:package_version).returns('1.0.0')
      @spec.stubs(:valid_publish_config?).returns(true)

      @spec.stubs(:publish_config_access).returns('restricted')
      @spec.stubs(:enforce_publish_config?).returns(true)
      @spec.stubs(:registry).returns('fake')

      generate_npmrc = 'generate-local-npmrc "fake"'
      npm_publish = 'npm publish --tag latest --access restricted'
      deploy_steps = ['assert-npm-version-tag', generate_npmrc, npm_publish]
      assert_equal deploy_steps, @spec.deploy_steps
    end

    test 'yarn checklist takes precedence over npm checklist' do
      @spec.stubs(:yarn?).returns(true).at_least_once
      assert_match(/yarn version/, @spec.review_checklist[0])
    end

    test "max_divergence_commits defaults to `nil" do
      @spec.expects(:load_config).returns({})
      assert_nil @spec.max_divergence_commits
    end

    test "max_divergence_age defaults to `nil` if `merge.max_divergence.age` cannot be parsed" do
      @spec.expects(:load_config).returns(
        'merge' => {
          'max_divergence' => {
            'age' => 'badbadbad',
          },
        },
      )
      assert_nil @spec.max_divergence_age
    end
  end
end
