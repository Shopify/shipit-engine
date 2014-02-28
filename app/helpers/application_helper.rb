module ApplicationHelper
  def stacks
    @stacks ||= Stack.all
  end

  def is_current_stack?(stack)
    @stack == stack
  end
end
