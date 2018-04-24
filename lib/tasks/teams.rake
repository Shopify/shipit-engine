namespace :teams do
  desc "Import the members of each team configured through the github_oauth.teams config and attempt to set a webhook to keep the list updated"
  task fetch: :environment do
    handles = Shipit.github_teams_handles
    if handles.empty?
      puts "github_oauth.teams is empty"
    else
      handles.each do |handle|
        puts "Fetching @#{handle} members"
        begin
          team = Shipit::Team.find_or_create_by_handle(handle)
          team.refresh_members!
        rescue Octokit::Unauthorized, Octokit::NotFound => error
          puts "Failed to fetch @#{handle} members. Do you have enough permissions?"
          puts "#{error.class}: #{error.message}"
        end
      end
    end
  end
end
