class StacksController < ApplicationController
  before_action :load_stack, only: %i(update destroy settings sync_webhooks sync_commits clear_git_cache refresh_statuses)

  def new
    @stack = Stack.new
  end

  def index
    @user_stacks = current_user.stacks_contributed_to

    @stacks = Stack.order('(undeployed_commits_count > 0) desc', deploys_count: :desc)
  end

  def show
    @stack = Stack.from_param(params[:id])
    return unless stale?(last_modified: @stack.updated_at)

    @deploys = @stack.deploys.order(id: :desc).preload(:since_commit, :until_commit, :user).limit(10)
    @commits = @stack.commits.reachable.preload(:author).order(id: :desc)
    if deployed_commit = @stack.last_deployed_commit
      @commits = @commits.where('id > ?', deployed_commit.id)
    end
    @commits = @commits.to_a
  end

  def create
    @stack = Stack.create(create_params)
    respond_with(@stack)
  end

  def destroy
    @stack.destroy!
    respond_with(@stack)
  end

  def settings
  end

  def update
    @stack.update(update_params)
    redirect_to settings_stack_path(@stack)
  end

  def sync_commits
    GithubSyncJob.enqueue(stack_id: @stack.id)
    redirect_to settings_stack_path(@stack)
  end

  def refresh_statuses
    RefreshStatusesJob.enqueue(stack_id: @stack.id)
    redirect_to settings_stack_path(@stack)
  end

  def sync_webhooks
    GithubSetupWebhooksJob.enqueue(stack_id: @stack.id)
    redirect_to settings_stack_path(@stack)
  end

  def clear_git_cache
    ClearGitCacheJob.enqueue(stack_id: @stack.id)
    redirect_to settings_stack_path(@stack)
  end

  private

  def load_stack
    @stack = Stack.from_param(params[:id])
  end

  def create_params
    params.require(:stack).permit(:repo_name, :repo_owner, :environment, :branch, :deploy_url)
  end

  def update_params
    params.require(:stack).permit(:checklist, :deploy_url, :deploys_count, :lock_reason, :continuous_deployment, :reminder_url)
  end
end
