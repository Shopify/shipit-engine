class Deploy < ActiveRecord::Base
  belongs_to :stack
  belongs_to :since_commit, class_name: "Commit"
  belongs_to :until_commit, class_name: "Commit"

  has_many :chunks, class_name: 'OutputChunk'

  state_machine :status, initial: :pending do

    event :run do
      transition pending: :running
    end

    event :fail do
      transition running: :failed
    end

    event :complete do
      transition running: :success
    end

    state :pending
    state :running
    state :failed
    state :success
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
