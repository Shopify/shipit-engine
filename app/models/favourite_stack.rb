class FavouriteStack < ActiveRecord::Base
  belongs_to :user
  belongs_to :stack

  validates :user,     presence: true

  validates :stack,    presence: true

  validates :stack_id, uniqueness: {
    scope:   :user_id,
    message: 'is already favourited.',
  }
end
