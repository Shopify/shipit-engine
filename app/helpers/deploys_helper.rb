module DeploysHelper
  def render_checklist(checklist)
    return '' if checklist.blank?
    render 'deploys/checklist', checklist: checklist
  end

  def render_monitoring(stack)
    return '' unless stack.monitoring?
    render 'deploys/monitoring', stack: stack
  end

  def render_monitoring_panel(panel_spec)
    if url = panel_spec['image']
      image_tag(url, panel_spec.slice('height', 'width', 'alt'))
    elsif url = panel_spec['iframe']
      content_tag(:iframe, panel_spec.slice('height', 'width').merge('src' => url))
    else
      content_tag(:span, "#{panel_spec.inspect} is not a valid monitoring panel spec")
    end
  end
end
