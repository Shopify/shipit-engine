require 'test_helper'

class DeploysTest < ActiveSupport::TestCase
  def setup
    @deploy = deploys(:shipit)
  end

  test "working_directory" do
    assert_equal File.join(@deploy.stack.deploys_path, @deploy.id.to_s), @deploy.working_directory
  end
end
