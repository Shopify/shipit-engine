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
      Shipit requires a GitHub application to authenticate users.
      If you haven't created an application on GitHub yet, you can do so in the
      #{ link_to 'Settings', 'https://github.com/settings/applications/new', target: '_blank' }
      section of your profile. You can also create applications for organizations.
    MESSAGE
  end

  def missing_github_oauth_id_message
    (<<-MESSAGE).html_safe
      Copy the Client ID from your GitHub application,
      and paste it into the secrets.yml file under <code>github_oauth.id</code>.
     MESSAGE
  end

  def missing_github_oauth_secret_message
    (<<-MESSAGE).html_safe
      Copy the Client Secret from your GitHub application,
      and paste it into the secrets.yml file under <code>github_oauth.secret</code>.
     MESSAGE
  end

  def missing_github_api_credentials_message
    (<<-MESSAGE).html_safe
      Shipit needs API access to GitHub. You can
      #{ link_to 'create an access token', 'https://github.com/settings/tokens', target: '_blank' }
      with the following permissions:
      <code>admin:repo_hook</code>, <code>admin:org_hook</code> and <code>repo</code>
      and add it to the secrets.yml file under the key <code>github_api.access_token</code>.
    MESSAGE
  end

  def missing_redis_url_message
    (<<-MESSAGE).html_safe
      Shipit needs a Redis server. Please configure the Redis URL in the secrets.yml file of your app,
      under the key <code>redis_url</code>.
    MESSAGE
  end

  def missing_host_message
    (<<-MESSAGE).html_safe
      Shipit needs the host of the application before generating links in background jobs.
      Add the host name to the secrets.yml file, under the <code>host</code> key.
    MESSAGE
  end
end
