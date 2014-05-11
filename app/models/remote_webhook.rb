class RemoteWebhook < ActiveRecord::Base
  include SecureCompare
  belongs_to :stack

  def verify_signature(signature, message)
    algorithm, signature = signature.split("=", 2)
    return false unless algorithm == 'sha1'

    secure_compare(signature, OpenSSL::HMAC.hexdigest(algorithm, secret, message))
  end
end
