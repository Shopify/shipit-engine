class StacksController < ShipitController
  before_action :load_stack, only: %i(update destroy settings sync_webhooks clear_git_cache refresh ignore_ci)

  def new
    @stack = Stack.new
  end

  def index
    @user_stacks = current_user.stacks_contributed_to

    @stacks = Stack.order('(undeployed_commits_count > 0) desc', tasks_count: :desc)
  end

  def show
    @stack = Stack.from_param!(params[:id])
    return if flash.empty? && !stale?(last_modified: @stack.updated_at)

    @tasks = @stack.tasks.order(id: :desc).preload(:since_commit, :until_commit, :user).limit(10)
    @commits = @stack.commits.reachable.preload(:author, :statuses).order(id: :desc)
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
    @stack.schedule_for_destroy!
    redirect_to stacks_url
  end

  def settings
  end

  def refresh
    RefreshStatusesJob.perform_later(stack_id: @stack.id)
    GithubSyncJob.perform_later(stack_id: @stack.id)
    flash[:success] = 'Refresh scheduled'
    redirect_to :back
  end

  def update
    @stack.update(update_params)
    redirect_to params[:return_to].presence || stack_settings_path(@stack)
  end

  def sync_webhooks
    @stack.setup_hooks
    redirect_to stack_settings_path(@stack)
  end

  def clear_git_cache
    ClearGitCacheJob.perform_later(@stack)
    redirect_to stack_settings_path(@stack)
  end

  private

  def load_stack
    @stack = Stack.from_param!(params[:id])
  end

  def create_params
    params.require(:stack).permit(:repo_name, :repo_owner, :environment, :branch, :deploy_url, :ignore_ci)
  end

  def update_params
    params.require(:stack).permit(:deploy_url, :lock_reason, :continuous_deployment, :ignore_ci).tap do |params|
      params[:lock_author_id] = params[:lock_reason].present? ? current_user.id : nil
    end
  end
end
