class RemoveAllGithubHooks < ActiveRecord::Migration[5.1]
  def change
    if !Shipit.legacy_github_api && Shipit::GithubHook.any?
      Rails.logger.error("Can't destroy github hooks because no legacy token is configred")
    else
      Shipit::GithubHook.find_each do |hook|
        Shipit::DestroyJob.perform_later(hook)
      end
    end
  end
end
