namespace :team do
  desc "Import a team and it's members from Github and install a webhook to monitor it"
  task fetch: :environment do
    handle = ENV['HANDLE']
    team = Team.find_or_create_by_handle(handle)
    fail "Could not find team with handle: #{handle}" unless team
    team.setup_hooks(async: false)
    team.refresh_members!
  end
end
