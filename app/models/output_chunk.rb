class OutputChunk < ActiveRecord::Base
  belongs_to :deploy

  scope :tail, -> (start) { where('id > ?', start || 0) }
end
