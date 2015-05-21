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
      Shipit needs to be configured with a GitHub Application to work properly.
      If you haven't created an application on GitHub yet, you can do so in the
      #{ link_to 'Settings', 'https://github.com/settings/applications/new' }
      section of your profile. You can also create applications for organizations.
    MESSAGE
  end

  def missing_github_oauth_id_message
    (<<-MESSAGE)
      From the GitHub Application, copy the Client ID to the secrets.yml file,
      under the key github_oauth.id
     MESSAGE
  end

  def missing_github_oauth_secret_message
    (<<-MESSAGE)
      From the GitHub Application, copy the Client Secret to the secrets.yml file,
      under the key github_oauth.secret
     MESSAGE
  end

  def missing_github_api_credentials_message
    (<<-MESSAGE).html_safe
      Shipit requires API access to GitHub. You can create
      #{ link_to 'access tokens', 'https://github.com/settings/tokens' }
      and add it to the secrets.yml file under the key github_api.access_token
    MESSAGE
  end

  def missing_redis_url_message
    (<<-MESSAGE)
      Redis is required to run Shipit. Please configure the redis_url in the secrets.yml file
      of your app, under the key redis_url
    MESSAGE
  end

  def missing_host_message
    (<<-MESSAGE)
      The host of the application is required when Shipit generates links in background jobs.
      Add it to the secrets.yml file, under the key host.
    MESSAGE
  end
end
