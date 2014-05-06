class Webhook < ActiveRecord::Base
  belongs_to :stack

  def verify_signature(signature, message)
    algorithm, signature = signature.split("=", 2)
    signature == OpenSSL::HMAC.hexdigest(algorithm, secret, message)
  end
end
