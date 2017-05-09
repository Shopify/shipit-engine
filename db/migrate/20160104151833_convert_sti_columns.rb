class ConvertStiColumns < ActiveRecord::Migration[4.2]
  def up
    Shipit::Task.where(type: 'Task').update_all(type: 'Shipit::Task')
    Shipit::Task.where(type: 'Deploy').update_all(type: 'Shipit::Deploy')
    Shipit::Task.where(type: 'Rollback').update_all(type: 'Shipit::Rollback')

    Shipit::GithubHook.where(type: 'GithubHook::Repo').update_all(type: 'Shipit::GithubHook::Repo')
    Shipit::GithubHook.where(type: 'GithubHook::Organization').update_all(type: 'Shipit::GithubHook::Organization')
  end
end
