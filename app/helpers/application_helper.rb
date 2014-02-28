module ApplicationHelper
  def stacks
    @stacks ||= Stacks.all
  end
end
