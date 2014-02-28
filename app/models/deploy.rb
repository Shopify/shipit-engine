class Deploy < ActiveRecord::Base
  belongs_to :stack
  belongs_to :since_commit, class_name: "Commit"
  belongs_to :until_commit, class_name: "Commit"

  has_many :chunks, class_name: 'OutputChunk'

  state_machine :status, :initial => :undeployed do
    event :enqueued do
      transition [:undeployed] => :pending
    end

    event :started do
      transition [:pending] => :running
    end

    event :failed do
      transition [:pending, :running] => :failed
    end

    event :deployed do
      transition [:running] => :succeeded
    end
  end

  def working_directory
    File.join(stack.deploys_path, id.to_s)
  end

  def write(text)
    chunks.create!(text: text)
  end

  def display_output
    if output?
      output
    else
      chunks.pluck(:text).join
    end
  end
end
