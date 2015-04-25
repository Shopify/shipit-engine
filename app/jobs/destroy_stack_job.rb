class DestroyStackJob < BackgroundJob
  @queue = :default

  def perform(params)
    stack = Stack.find(params[:stack_id])
    stack.destroy!
  end
end
