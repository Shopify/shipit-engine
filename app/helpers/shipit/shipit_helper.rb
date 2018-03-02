module Shipit
  module ShipitHelper
    def subscribe(url, *selectors)
      content_for(:update_subscription) do
        [
          tag('meta', name: 'subscription-channel', content: url),
          *selectors.map { |s| tag('meta', name: 'subscription-selector', content: s) },
        ].join("\n").html_safe
      end
    end

    def emojify(content)
      if content.present?
        h(content).to_str.gsub(/:([\w+-]+):/) do |match|
          if emoji = Emoji.find_by_alias($1)
            %(
              <img
                alt="##{$1}"
                src="#{image_path("emoji/#{emoji.image_filename}")}"
                style="vertical-align:middle"
                width="20"
                height="20"
              />
            )
          else
            match
          end
        end.html_safe
      end
    end

    def include_plugins(stack)
      safe_join(stack.plugins.flat_map { |plugin, config| plugin_tags(plugin, config) })
    end

    def plugin_tags(plugin, config)
      tags = []
      tags << tag('meta', name: "#{plugin}-config", content: config.to_json) if config
      tags << javascript_include_tag("plugins/#{plugin}")
      tags << stylesheet_link_tag("plugins/#{plugin}")
      tags
    end

    def missing_github_oauth_message
      <<-MESSAGE.html_safe
        Shipit requires a GitHub application to authenticate users.
        If you haven't created an application on GitHub yet, you can do so in the
        #{link_to 'Settings', Shipit.github_url('/settings/applications/new'), target: '_blank'}
        section of your profile. You can also create applications for organizations.
        When setting up your application in Github, set the Homepage URL to your domain
        and the Authorization callback URL to '<yourdomain>/github/auth/github/callback'.
      MESSAGE
    end

    def missing_github_oauth_id_message
      <<-MESSAGE.html_safe
        Copy the Client ID from your GitHub application,
        and paste it into the secrets.yml file under <code>github_oauth.id</code>.
       MESSAGE
    end

    def missing_github_oauth_secret_message
      <<-MESSAGE.html_safe
        Copy the Client Secret from your GitHub application,
        and paste it into the secrets.yml file under <code>github_oauth.secret</code>.
       MESSAGE
    end

    def missing_github_api_credentials_message
      <<-MESSAGE.html_safe
        Shipit needs API access to GitHub. You can
        #{link_to 'create an access token', Shipit.github_url('/settings/tokens'), target: '_blank'}
        with the following permissions:
        <code>admin:repo_hook</code>, <code>admin:org_hook</code> and <code>repo</code>
        and add it to the secrets.yml file under the key <code>github_api.access_token</code>.
      MESSAGE
    end

    def missing_redis_url_message
      <<-MESSAGE.html_safe
        Shipit needs a Redis server. Please configure the Redis URL in the secrets.yml file of your app,
        under the key <code>redis_url</code>.
      MESSAGE
    end

    def missing_host_message
      <<-MESSAGE.html_safe
        Shipit needs the host of the application before generating links in background jobs.
        Add the host name to the secrets.yml file, under the <code>host</code> key.
      MESSAGE
    end
  end
end
