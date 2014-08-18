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

  def can_login?
    Settings.github && !current_user.logged_in?
  end

  def emoji_tag(emoji)
    image_tag("emoji/#{emoji}.png", height: 20, width: 20, alt: ":#{emoji}:")
  end

  def include_plugins
    tags = []
    Rails.application.config.assets.paths.each do |path|
      Dir[File.join(path, 'plugins/*')].each do |plugin_path|
        tags << include_plugin_asset_tag(File.basename(plugin_path))
      end
    end
    tags.join.html_safe
  end

  def include_plugin_asset_tag(plugin)
    if plugin =~ /\A([\-\w]+)(\.js)?(\.coffee)?\Z/
      javascript_include_tag "plugins/#{$1}"
    elsif plugin =~ /\A([\-\w]+)(\.css)?(\.scss)?\Z/
      stylesheet_link_tag "plugins/#{$1}"
    end
  end

end
