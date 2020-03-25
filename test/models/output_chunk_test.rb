# typed: false
require 'test_helper'

module Shipit
  class OutputChunkTest < ActiveSupport::TestCase
    def setup
      @deploy = shipit_deploys(:shipit)
      @chunks = 3.times.map { OutputChunk.create!(text: 'bla', task: @deploy) }
    end

    test "tail" do
      start = @chunks.first
      rest = @chunks - [start]
      assert_equal rest, @deploy.chunks.tail(start.id)
    end

    test "tail without start" do
      assert_equal @deploy.chunks, @deploy.chunks.tail(nil)
    end
  end
end
