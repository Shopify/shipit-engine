class OutputChunk < ActiveRecord::Base
  belongs_to :task

  scope :tail, -> (start) { where('id > ?', start || 0) }

  def text=(string)
    super(string.force_encoding(Encoding::UTF_8).scrub)
  end
end
