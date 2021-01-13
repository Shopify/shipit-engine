# frozen_string_literal: true
# rubocop:disable Lint/MissingSuper
require 'pathname'
require 'fileutils'

module Shipit
  class PredictiveBuildCommands < Commands
    
    def initialize(predictive_build, stack, chdir=nil)
      @stack = stack
      @chdir = chdir || File.join(@stack.builds_path, @stack.repo_name)
    end

    def git_clone(repo_name=nil, chdir: nil, **kwargs)
      git('clone', '--recursive', '--branch',
          @stack.branch, @stack.repo_git_url, repo_name || @stack.repo_name, chdir: chdir || @stack.builds_path,
          env: env, **kwargs)
    end

    def git_fetch(branch = nil)
      git('fetch', 'origin', '--tags', branch || @stack.branch, env: env, chdir: @chdir)
    end

    def git_merge_origin_as_pr(branch, pr_num)
      git('merge', "origin/#{branch}", '--no-ff', '-m',
          "Merge pull request ##{pr_num} from vcita/#{branch}", chdir: @chdir, env: env)
    end

    def git_merge_ff(branch)
      git('merge', "origin/#{branch}", '--ff-only', chdir: @chdir, env: env)
    end

    def git_checkout(branch)
      git('checkout', '-b', branch, chdir: @chdir, env: env)
    end

    def git_push(force = true)
      git('push', (force ? '-f' : ''), '-u', 'origin', 'HEAD', chdir: @chdir, env: env)
    end

    def git_reset(to)
      git('reset', '--hard', to, chdir: @chdir, env: env)
    end

    def git_clean
      git('clean', '-ffdx', chdir: @chdir, env: env)
    end

    def git_rev_parse(branch, repo_url)
      git('clean', 'rev-parse', '--verify', branch, repo_url)
    end

    def create_directories
      FileUtils.mkdir_p(@stack.builds_path)
    end
  end
end
