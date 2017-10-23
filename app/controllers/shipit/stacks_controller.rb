module Shipit
  class StacksController < ShipitController
    before_action :load_stack, only: %i(update destroy settings sync_webhooks clear_git_cache refresh)

    def new
      @stack = Stack.new
    end

    def index
      @user_stacks = current_user.stacks_contributed_to

      @stacks = Stack.order('(undeployed_commits_count > 0) desc', tasks_count: :desc).to_a
    end

    def show
      @stack = Stack.from_param!(params[:id])
      return if flash.empty? && !stale?(last_modified: @stack.updated_at)

      @tasks = @stack.tasks.order(id: :desc).preload(:since_commit, :until_commit, :user).limit(10)
      @commits = @stack.undeployed_commits { |scope| scope.preload(:author, :statuses) }
    end

    def lookup
      @stack = Stack.find(params[:id])
      redirect_to stack_url(@stack)
    end

    def create
      @stack = Stack.new(create_params)
      unless @stack.save
        flash[:warning] = @stack.errors.full_messages.to_sentence
      end
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
      redirect_to request.referer.presence || stack_path(@stack)
    end

    def update
      options = {}
      unless @stack.update(update_params)
        options = {flash: {warning: @stack.errors.full_messages.to_sentence}}
      end

      reason = params[:stack][:lock_reason]
      if reason.present?
        @stack.lock(reason, current_user)
      elsif @stack.locked?
        @stack.unlock
      end

      redirect_to(params[:return_to].presence || stack_settings_path(@stack), options)
    end

    def sync_webhooks
      @stack.setup_hooks
      redirect_to stack_settings_path(@stack)
    end

    def clear_git_cache
      ClearGitCacheJob.perform_later(@stack)
      flash[:success] = 'Git Cache clearing scheduled'
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
      params.require(:stack).permit(
        :deploy_url,
        :environment,
        :continuous_deployment,
        :ignore_ci,
        :merge_queue_enabled,
      )
    end
  end
end
