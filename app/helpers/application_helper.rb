module ApplicationHelper
  def stacks
    @stacks ||= Stack.all
  end
end
