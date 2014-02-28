require 'faker'

users = 3.times.map do
  User.create!(
    :name  => Faker::Name.name,
    :email => Faker::Internet.email,
    :login => Faker::Internet.user_name
  )
end

stacks = 3.times.map do
  Stack.create!(
    :repo_name  => Faker::Internet.domain_name.parameterize,
    :repo_owner => Faker::Company.name.parameterize
  )
end

commits = []

stacks.each do |stack|
  20.times do
    user = users.sample

    commits << Commit.create!(
      :stack_id     => stack.id,
      :author_id    => user.id,
      :committer_id => user.id,
      :sha          => SecureRandom.hex(20),
      :message      => Faker::Company.catch_phrase,
      :state        => %w(pending success error failure).sample
    )
  end
end
