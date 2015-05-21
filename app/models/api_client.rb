class ApiClient < ActiveRecord::Base
  InsufficientPermission = Class.new(StandardError)

  belongs_to :creator, class_name: 'User'
  belongs_to :stack

  validates :creator, :name, presence: true

  serialize :permissions, Array
  PERMISSIONS = %w(
    read:stack
    write:stack
    deploy:stack
    lock:stack
    read:hook
    write:hook
  ).freeze
  validates :permissions, subset: {of: PERMISSIONS}

  class << self
    def authenticate(token)
      find_by_id(message_verifier.verify(token).to_i)
    rescue Shipit::SimpleMessageVerifier::InvalidSignature
    end

    def message_verifier
      @message_verifier ||= Shipit::SimpleMessageVerifier.new(Shipit.api_clients_secret)
    end
  end

  def authentication_token
    self.class.message_verifier.generate(id)
  end

  def check_permissions!(operation, scope)
    required_permission = "#{operation}:#{scope}"
    unless permissions.include?(required_permission)
      raise InsufficientPermission, "This operation requires the `#{required_permission}` permission"
    end
    true
  end
end
