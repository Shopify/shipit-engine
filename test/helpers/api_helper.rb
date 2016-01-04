module ApiHelper
  private

  def authenticate!(client = @client || :spy)
    client = shipit_api_clients(client) if client.is_a?(Symbol)
    @client ||= client
    request.headers['Authorization'] = "Basic #{Base64.encode64(client.authentication_token)}"
  end
end
