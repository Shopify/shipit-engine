class ApiClient < ActiveRecord::Base
  belongs_to :creator, class_name: 'User'

  validates :creator, presence: true

  serialize :permissions, Array

  class << self
    def authenticate(token)
      find_by_id(message_verifier.verify(token).to_i)
    rescue SimpleMessageVerifier::InvalidSignature
    end

    def message_verifier
      @message_verifier ||= SimpleMessageVerifier.new(Shipit.api_clients_secret)
    end
  end

  def authentication_token
    self.class.message_verifier.generate(id)
  end
end
