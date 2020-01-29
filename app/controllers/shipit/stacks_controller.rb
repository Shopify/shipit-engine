module Shipit
  class StacksController < ShipitController
    before_action :load_stack, only: %i(update destroy settings statistics clear_git_cache refresh)

    def new
      @stack = Stack.new
    end

    def index
      @user_stacks = current_user.stacks_contributed_to

      @stacks = Stack.order(Arel.sql('(undeployed_commits_count > 0) desc'), tasks_count: :desc)

      @show_archived = params[:show_archived]
      @stacks = @stacks.not_archived unless @show_archived

      @stacks = @stacks.to_a
    end

    def show
      @stack = Stack.from_param!(params[:id])
      return if flash.empty? && !stale?(last_modified: @stack.updated_at)

      @tasks = @stack.tasks.order(id: :desc).preload(:since_commit, :until_commit, :user).limit(10)

      commits = @stack.undeployed_commits do |scope|
        scope.preload(:author, :statuses, :check_runs, :lock_author)
      end

      next_expected_commit_to_deploy = @stack.next_expected_commit_to_deploy(commits: commits)

      @active_commits = []
      @undeployed_commits = []

      commits.each do |commit|
        (commit.active? ? @active_commits : @undeployed_commits) << commit
      end

      @active_commits = map_to_undeployed_commit(
        @active_commits,
        next_expected_commit_to_deploy: next_expected_commit_to_deploy,
      )
      @undeployed_commits = map_to_undeployed_commit(
        @undeployed_commits,
        next_expected_commit_to_deploy: next_expected_commit_to_deploy,
      )
    end

    def lookup
      @stack = Stack.find(params[:id])
      redirect_to stack_url(@stack)
    end

    def create
      @stack = Stack.new(create_params)
      @stack.repository = repository
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

    def statistics
      previous_deploy_stats = Shipit::DeployStats.new(@stack.deploys.not_active.previous_seven_days)
      @deploy_stats = Shipit::DeployStats.new(@stack.deploys.not_active.last_seven_days)
      if @deploy_stats.empty?
        flash[:warning] = 'Statistics not available without previous deploys'
        return redirect_to stack_path(@stack)
      end
      @diffs = @deploy_stats.compare(previous_deploy_stats)
    end

    def refresh
      RefreshStatusesJob.perform_later(stack_id: @stack.id)
      RefreshCheckRunsJob.perform_later(stack_id: @stack.id)
      GithubSyncJob.perform_later(stack_id: @stack.id)
      flash[:success] = 'Refresh scheduled'
      redirect_to request.referer.presence || stack_path(@stack)
    end

    def update
      options = {}
      unless @stack.update(update_params)
        options = {flash: {warning: @stack.errors.full_messages.to_sentence}}
      end

      update_lock
      update_archived

      redirect_to(params[:return_to].presence || stack_settings_path(@stack), options)
    end

    def clear_git_cache
      ClearGitCacheJob.perform_later(@stack)
      flash[:success] = 'Git Cache clearing scheduled'
      redirect_to stack_settings_path(@stack)
    end

    private

    def update_lock
      if params[:stack].key?(:lock_reason)
        reason = params[:stack][:lock_reason]
        if reason.present?
          @stack.lock(reason, current_user)
        elsif @stack.locked?
          @stack.unlock
        end
      end
    end

    def update_archived
      if params[:stack][:archived].present?
        if params[:stack][:archived] == "true"
          @stack.archive!(current_user)
        elsif @stack.archived?
          @stack.unarchive!
        end
      end
    end

    def map_to_undeployed_commit(commits, next_expected_commit_to_deploy:)
      commits.map.with_index do |c, i|
        index = commits.size - i - 1
        UndeployedCommit.new(c, index: index, next_expected_commit_to_deploy: next_expected_commit_to_deploy)
      end
    end

    def load_stack
      @stack = Stack.from_param!(params[:id])
    end

    def create_params
      params.require(:stack).permit(:environment, :branch, :deploy_url, :ignore_ci)
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

    def repository
      @repository ||= Repository.find_or_create_by(owner: repo_owner, name: repo_name)
    end

    def repo_owner
      repository_params[:repo_owner]
    end

    def repo_name
      repository_params[:repo_name]
    end

    def repository_params
      params.require(:stack).permit(:repo_owner, :repo_name)
    end
  end
end
