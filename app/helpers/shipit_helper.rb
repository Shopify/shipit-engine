module ShipitHelper
  def stacks
    @stacks ||= Stack.all
  end

  def stacks_by_owner
    @stacks_by_owner ||= stacks.group_by(&:repo_owner)
  end

  def emoji_tag(emoji)
    image_tag("emoji/#{emoji}.png", height: 20, width: 20, alt: ":#{emoji}:")
  end

  def include_plugins
    tags = []
    Rails.application.config.assets.paths.each do |path|
      Dir[File.join(path, 'plugins/*')].each do |plugin_path|
        tags << include_plugin_asset_tag(File.basename(plugin_path)) if File.file?(plugin_path)
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

  def missing_github_oauth_message
    (<<-MESSAGE).html_safe
      Shipit needs to be configured with a Github Application to work properly.
      If you haven't created an application on Github yet, you can do so in
      the #{ link_to 'Settings', 'https://github.com/settings/applications/new' }
      section of your profile. You can also create applications for organizations.
    MESSAGE
  end

  def missing_github_oauth_id_message
    (<<-MESSAGE).html_safe
      From the Github Application, copy the Client ID to the shipit.yml file,
      under github_oauth.id
     MESSAGE
  end

  def missing_github_oauth_secret_message
    (<<-MESSAGE).html_safe
      From the Github Application, copy the Client Secret to the shipit.yml file,
      under github_oauth.secret
     MESSAGE
  end

  def missing_github_api_credentials_message
    (<<-MESSAGE).html_safe
      Shipit requires API access to Github. You can create
      #{ link_to 'access tokens', 'https://github.com/settings/tokens' }
      and add it to the secrets.yml file under github_api.access_token
    MESSAGE
  end
end
