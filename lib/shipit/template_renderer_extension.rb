module TemplateRendererExtension
  private

  def render_template(template, layout_name = nil, *args)
    if layout_name && bootstrap?(template)
      layout_name = 'layouts/shipit_bootstrap'
    end
    super(template, layout_name, *args)
  end

  def bootstrap?(template)
    template.identifier.start_with?('bootstrap/') || template.identifier.start_with?("#{Shipit.bootstrap_view_path}/")
  end
end

ActionView::TemplateRenderer.prepend(TemplateRendererExtension)
