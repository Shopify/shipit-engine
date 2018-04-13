module Shipit
  class GitHubApp
    def initialize(config)
      @webhook_secret = config[:webhook_secret]
      @private_key = config[:private_key]
    end

    def verify_webhook_signature(signature, message)
      return true unless webhook_secret.present?

      algorithm, signature = signature.split("=", 2)
      return false unless algorithm == 'sha1'

      SecureCompare.secure_compare(signature, OpenSSL::HMAC.hexdigest(algorithm, webhook_secret, message))
    end

    private

    attr_reader :webhook_secret, :private_key
  end
end
