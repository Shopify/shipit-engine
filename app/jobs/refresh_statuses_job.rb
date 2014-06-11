class RefreshStatusesJob < BackgroundJob
  @queue = :default

  self.timeout = 60

  def perform(params)
    stack = Stack.find(params[:stack_id])
    stack.commits.order(id: :desc).limit(30).each(&:refresh_status)
  end

end
