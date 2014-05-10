class StacksController < ApplicationController
  before_action :load_stack, only: %i(update destroy settings sync_remote_webhooks sync_commits clear_git_cache)

  def new
    @stack = Stack.new
  end

  def index
    @stacks = Stack.all
  end

  def show
    @stack = Stack.from_param(params[:id])
    return unless stale?(last_modified: [menu.updated_at, @stack.updated_at].max)

    @deploys = @stack.deploys.order(id: :desc).preload(:since_commit, :until_commit, :user).limit(10)
    @commits = @stack.commits.reachable.preload(:author).order(id: :desc)
    if deployed_commit = @stack.last_deployed_commit
      @commits = @commits.where('id > ?', deployed_commit.id)
    end
    @commits = @commits.to_a
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

  def update
    @stack.update(params.require(:stack).permit(:checklist, :deploy_url))
    redirect_to settings_stack_path(@stack)
  end

  def sync_commits
    Resque.enqueue(GithubSyncJob, stack_id: @stack.id)
    redirect_to settings_stack_path(@stack)
  end

  def sync_remote_webhooks
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
    params.require(:stack).permit(:repo_name, :repo_owner, :environment, :branch, :deploy_url)
  end
end
