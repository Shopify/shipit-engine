# frozen_string_literal: true

module Shipit
  class OutputChunk < Record
    belongs_to :task

    scope :tail, ->(start) { order(id: :asc).where('id > ?', start || 0) }

    def text=(string)
      if string.frozen?
        super(string)
      else
        super(string.force_encoding(Encoding::UTF_8).scrub)
      end
    end
  end
end
