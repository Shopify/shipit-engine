class OutputChunk < ActiveRecord::Base
  belongs_to :task

  scope :tail, -> (start) { where('id > ?', start || 0) }
end
