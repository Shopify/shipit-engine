# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module Shipit
  class DeploySpec
    class FileSystemTest < ActiveSupport::TestCase
      test 'deploy.pre calls "exit 1" if there is a bare shipit file and Shipit is configured to ignore' do
        Shipit.expects(:respect_bare_shipit_file?).returns(false).at_least_once
        deploy_spec = Shipit::DeploySpec::FileSystem.new(Dir.tmpdir, 'env')
        deploy_spec.expects(:config_file_path).returns(Pathname.new(Dir.tmpdir) + '/shipit.yml').at_least_once
        deploy_spec.expects(:read_config).never
        pre_commands = deploy_spec.send(:config, 'deploy', 'pre')
        assert pre_commands.include?('exit 1')
        assert pre_commands.first.include?('configured to ignore')
        refute pre_commands.include?('test 2')
      end

      test 'deploy.pre does not call "exit 1" if Shipit is not configured to do so' do
        Shipit.expects(:respect_bare_shipit_file?).returns(true).at_least_once
        deploy_spec = Shipit::DeploySpec::FileSystem.new(Dir.tmpdir, 'env')
        deploy_spec.expects(:config_file_path).returns(Pathname.new(Dir.tmpdir) + '/shipit.yml').at_least_once
        deploy_spec.expects(:read_config).returns(SafeYAML.load(deploy_spec_yaml))
        pre_commands = deploy_spec.send(:config, 'deploy', 'pre')
        refute pre_commands.include?('exit 1')
        assert pre_commands.include?('test 2')
      end

      test 'Shipit.respect_bare_shipit_file? has no effect if the file is not a bare file' do
        [true, false].each do |obey_val|
          Shipit.expects(:respect_bare_shipit_file?).returns(obey_val).at_least_once
          deploy_spec = Shipit::DeploySpec::FileSystem.new(Dir.tmpdir, 'env')
          deploy_spec.expects(:config_file_path).returns(Pathname.new(Dir.tmpdir) + '/shipit.env.yml').at_least_once
          deploy_spec.expects(:read_config).returns(SafeYAML.load(deploy_spec_yaml))
          pre_commands = deploy_spec.send(:config, 'deploy', 'pre')
          refute pre_commands.include?('exit 1')
          assert pre_commands.include?('test 2')
        end
      end

      test '#load_config does not error if the file is empty' do
        Shipit.expects(:respect_bare_shipit_file?).returns(true).at_least_once
        deploy_spec = Shipit::DeploySpec::FileSystem.new(Dir.tmpdir, 'env')
        deploy_spec.expects(:config_file_path).returns(Pathname.new(Dir.tmpdir) + '/shipit.env.yml').at_least_once
        deploy_spec.expects(:read_config).at_least_once.returns(false)
        loaded_config = deploy_spec.send(:cacheable_config)
        refute loaded_config == false
      end

      test '#load_config does not error if there is no "deploy" key' do
        Shipit.expects(:respect_bare_shipit_file?).returns(false).at_least_once
        deploy_spec = Shipit::DeploySpec::FileSystem.new(Dir.tmpdir, 'env')
        deploy_spec.expects(:config_file_path).returns(Pathname.new(Dir.tmpdir) + '/shipit.yml').at_least_once
        deploy_spec.expects(:read_config).never
        loaded_config = deploy_spec.send(:load_config)
        assert loaded_config.key?("deploy")
        assert loaded_config["deploy"].key?("pre")
        assert loaded_config["deploy"]["pre"].include?('exit 1')
      end

      def deploy_spec_yaml
        <<~EOYAML
          deploy:
            pre:
              - test 2
            override:
              - test 1
        EOYAML
      end

      def deploy_spec_missing_deploy_yaml
        <<~EOYAML
          production_platform:
            application: test-application
            runtime_ids:
              - production-unrestricted-1234
        EOYAML
      end
    end
  end
end
