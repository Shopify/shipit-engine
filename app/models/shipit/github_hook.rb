module Shipit
  class GithubHook < ActiveRecord::Base
    include SecureCompare

    belongs_to :stack, required: false # Required for fixtures

    before_create :generate_secret
    before_destroy :teardown!

    def verify_signature(signature, message)
      algorithm, signature = signature.split("=", 2)
      return false unless algorithm == 'sha1'

      secure_compare(signature, OpenSSL::HMAC.hexdigest(algorithm, secret, message))
    end

    delegate :github_repo_name, to: :stack
    def setup!
      hook = already_setup? ? update_hook! : create_hook!
      update!(github_id: hook.id, api_url: hook.rels[:self].href)
    end

    def schedule_setup!
      SetupGithubHookJob.perform_later(self)
    end

    def teardown!
      destroy_hook! if already_setup?
      true
    end

    def event=(event)
      super(event.to_s)
    end

    def already_setup?
      github_id?
    end

    private

    def update_hook!
      edit_hook!
    rescue Octokit::NotFound
      create_hook!
    end

    def endpoint_url
      raise NotImplementedError.new('Subclasses must implement a `endpoint_url` method')
    end

    def hook_properties
      {url: endpoint_url, content_type: 'json', secret: secret}
    end

    def generate_secret
      self.secret = SecureRandom.hex
    end

    def url_helpers
      Shipit::Engine.routes.url_helpers
    end

    def host
      Shipit.host
    end

    def api
      Shipit.github_api
    end

    class Repo < GithubHook
      belongs_to :stack, required: true

      private

      def create_hook!
        api.create_hook(github_repo_name, 'web', properties, events: [event], active: true)
      end

      def edit_hook!
        api.edit_hook(github_repo_name, github_id, 'web', properties, events: [event], active: true)
      end

      def destroy_hook!
        api.remove_hook(github_repo_name, github_id)
      rescue Octokit::NotFound
      end

      def properties
        {
          url: endpoint_url,
          content_type: 'json',
          secret: secret,
        }
      end

      def endpoint_url
        case event
        when 'push'
          url_helpers.push_stack_webhooks_url(stack_id, host: host)
        when 'status'
          url_helpers.state_stack_webhooks_url(stack_id, host: host)
        else
          raise ArgumentError, "Unknown GithubHook::Repo event: `#{event.inspect}`"
        end
      end
    end

    class Organization < GithubHook
      validates :organization, presence: true

      private

      def create_hook!
        api.create_org_hook(organization, properties, events: [event], active: true)
      end

      def edit_hook!
        api.edit_org_hook(organization, github_id, properties, events: [event], active: true)
      end

      def destroy_hook!
        api.remove_org_hook(organization, github_id)
      rescue Octokit::NotFound
      end

      def properties
        {
          url: endpoint_url,
          content_type: 'json',
          secret: secret,
        }
      end

      def endpoint_url
        case event
        when 'membership'
          url_helpers.membership_webhooks_url(host: host)
        else
          raise ArgumentError, "Unknown GithubHook::Organization event: `#{event.inspect}`"
        end
      end
    end
  end
end
