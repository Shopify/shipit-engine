module ApiHelper
  private

  def authenticate!
    @client ||= api_clients(:spy)
    request.headers['Authorization'] = "Basic #{Base64.encode64(@client.authentication_token)}"
  end
end
