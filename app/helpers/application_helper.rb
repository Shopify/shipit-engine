module ApplicationHelper
  def stacks
    @stacks ||= Stack.all
  end

  def stacks_by_owner
    @stacks_by_owner ||= stacks.group_by(&:repo_owner)
  end

  def is_current_stack?(stack)
    @stack == stack
  end

  def emoji_tag(emoji)
    image_tag("emoji/#{emoji}.png", height: 20, width: 20, alt: ":#{emoji}:")
  end
end
