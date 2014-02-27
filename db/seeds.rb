require 'faker'

users = 3.times.map do
  User.create!(
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
