# frozen_string_literal: true

# The gem in unmaintained but using a deprecated API, this monkeypatches a fix:
# https://github.com/omniauth/omniauth-github/pull/84

module OmniAuthGitHubHeaderAuth
  def raw_info
    access_token.options[:mode] = :header
    @raw_info ||= access_token.get('user').parsed
  end

  def emails
    return [] unless email_access_allowed?
    access_token.options[:mode] = :header
    @emails ||= access_token.get('user/emails', headers: {'Accept' => 'application/vnd.github.v3'}).parsed
  end
end

OmniAuth::Strategies::GitHub.prepend(OmniAuthGitHubHeaderAuth)
