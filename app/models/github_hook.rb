class GithubHook < ActiveRecord::Base
  include SecureCompare
  belongs_to :stack, required: true

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
    Resque.enqueue(SetupGithubHookJob, hook_id: id)
  end

  def teardown!
    destroy_hook! if already_setup?
  end

  def event=(event)
    super(event.to_s)
  end

  def already_setup?
    github_id?
  end

  private

  def create_hook!
    Shipit.github_api.create_hook(github_repo_name, 'web', properties, events: [event], active: true)
  end

  def update_hook!
    Shipit.github_api.edit_hook(github_repo_name, github_id, 'web', properties, add_events: [event], active: true)
  rescue Octokit::NotFound
    create_hook!
  end

  def destroy_hook!
    Shipit.github_api.remove_hook(github_repo_name, github_id)
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
      raise ArgumentError, "Unknown GithubHook event: `#{event.inspect}`"
    end
  end

  def url_helpers
    Rails.application.routes.url_helpers
  end

  def host
    Shipit.host
  end

  def generate_secret
    self.secret = SecureRandom.hex
  end
end
