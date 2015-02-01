class RefreshStatusesJob < BackgroundJob
  @queue = :default

  self.timeout = 60

  def perform
    commits = stack.commits.order(id: :desc)
    if params[:commit_id]
      commits = commits.where(id: params[:commit_id])
    else
      commits = commits.limit(30)
    end

    commits.each(&:refresh_statuses)
  end

  def stack
    @stack ||= Stack.find(params[:stack_id])
  end
end
