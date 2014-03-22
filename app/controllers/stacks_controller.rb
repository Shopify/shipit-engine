class StacksController < ApplicationController
  before_action :load_stack, only: %i(destroy settings sync_webhooks sync_commits clear_git_cache)

  def new
    @stack = Stack.new
  end

  def index
    @stacks = Stack.all
  end

  def show
    @stack = Stack.from_param(params[:id])
    if stale?(@stack)
      @deploys = @stack.deploys.order(id: :desc).preload(:since_commit, :until_commit).limit(10)
      @commits = @stack.commits.preload(:author).order(id: :desc)
      if deployed_commit = @stack.last_deployed_commit
        @commits = @commits.where('id > ?', deployed_commit.id)
      end
      @commits = @commits.to_a
    end
  end

  def create
    @stack = Stack.create!(create_params)
    respond_with(@stack)
  end

  def destroy
    @stack.destroy!
    respond_with(@stack)
  end

  def settings
  end

  def sync_commits
    Resque.enqueue(GithubSyncJob, stack_id: @stack.id)
    redirect_to settings_stack_path(@stack)
  end

  def sync_webhooks
    Resque.enqueue(GithubSetupWebhooksJob, stack_id: @stack.id)
    redirect_to settings_stack_path(@stack)
  end

  def clear_git_cache
    Resque.enqueue(ClearGitCacheJob, stack_id: @stack.id)
    redirect_to settings_stack_path(@stack)
  end

  private

  def load_stack
    @stack = Stack.from_param(params[:id])
  end

  def create_params
    params.require(:stack).permit(:repo_name, :repo_owner, :environment, :branch)
  end
end
