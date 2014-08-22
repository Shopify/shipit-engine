module DeploysHelper

  def render_checklist(stack)
    return '' unless stack.checklist?
    render partial: 'deploys/checklist', stack: stack
  end

end
