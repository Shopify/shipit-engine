class StacksController < ApplicationController
  before_action :load_stack, only: [ :destroy, :settings, :sync_webhooks, :sync_commits ]

  def new
    @stack = Stack.new
  end

  def index
    @stacks = Stack.all
  end

  def show
    @stack   = Stack.preload(:commits => :author).from_param(params[:id])
    @deploys = @stack.deploys.order(id: :desc).preload(:since_commit, :until_commit).limit(10)
    @commits = @stack.commits.order(id: :desc).preload(:author)
    if deployed_commit = @stack.last_deployed_commit
      @commits = @commits.where('id > ?', deployed_commit.id)
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

  private

  def load_stack
    @stack = Stack.from_param(params[:id])
  end

  def create_params
    params.require(:stack).permit(:repo_name, :repo_owner, :environment, :branch)
  end
end
