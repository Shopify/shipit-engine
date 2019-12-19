class BackfillRepositoryData < ActiveRecord::Migration[6.0]
  def up
    repositories = {}
    Shipit::Stack.all.each do |stack|
      repo_owner = stack[:repo_owner].downcase
      repo_name = stack[:repo_name].downcase

      repository = (repositories[[repo_owner, repo_name]] ||= Shipit::Repository.create_or_find_by!(
        owner: repo_owner,
        name: repo_name,
      ))

      stack.update_column(:repository_id, repository.id)
    end
  end

  def down
    Shipit::Repository.find_each do |repository|
      repository.stacks.update_all(repo_owner: repository.owner, repo_name: repository.name)
    end
  end
end
