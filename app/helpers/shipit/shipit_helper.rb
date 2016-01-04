module Shipit
  module ShipitHelper
    def include_plugins(stack)
      stack.plugins.flat_map do |plugin, config|
        plugin_tags(plugin, config)
      end.join.html_safe
    end

    def plugin_tags(plugin, config)
      tags = []
      tags << tag('meta', name: "#{plugin}-config", content: config.to_json) if config
      tags << javascript_include_tag("plugins/#{plugin}")
      tags << stylesheet_link_tag("plugins/#{plugin}")
      tags
    end

    def missing_github_oauth_message
      (<<-MESSAGE).html_safe
        Shipit requires a GitHub application to authenticate users.
        If you haven't created an application on GitHub yet, you can do so in the
        #{link_to 'Settings', Shipit.github_url('/settings/applications/new'), target: '_blank'}
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
        #{link_to 'create an access token', Shipit.github_url('/settings/tokens'), target: '_blank'}
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
end
