class BackfillRepositoryData < ActiveRecord::Migration[6.0]
  def up
    repositories = Shipit::Stack.distinct.select(:repo_owner, :repo_name).pluck(:repo_owner, :repo_name)
    repositories.each do |repo_owner, repo_name|
      repository = Shipit::Repository.create_or_find_by(
        owner: repo_owner,
        name: repo_name,
      )

      stacks = Shipit::Stack.where(repo_owner: repository.owner, repo_name: repository.name)
      stacks.update(repository: repository)
    end
  end

  def down
    Shipit::Repository.find_each do |repository|
      repository.stacks.update_all(repo_owner: repository.owner, repo_name: repository.name)
    end
  end
end
