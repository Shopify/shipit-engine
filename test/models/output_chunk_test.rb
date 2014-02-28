require 'test_helper'

class OutputChunkTest < ActiveSupport::TestCase
  def setup
    @deploy = deploys(:shipit)
    @chunks = 3.times.map { OutputChunk.create!(text: 'bla', deploy: @deploy) }
  end

  test "tail" do
    start = @chunks.first
    rest  = @chunks - [start]
    assert_equal rest, @deploy.chunks.tail(start.id)
  end

  test "tail without start" do
    assert_equal @chunks, @deploy.chunks.tail(nil)
  end
end
