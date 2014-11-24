require 'test_helper'

class ConfigTest < ActiveSupport::TestCase
  setup do
    @config = Object.new.extend(Shipit::Config)
    @revision_file = Rails.root.join('REVISION')
  end

  teardown do
    @revision_file.unlink if @revision_file.exist?
  end

  test ".revision returns the content of the REVISION file if it is present" do
    @revision_file.write("foo\n")
    assert_equal "foo", @config.revision
  end

  test ".revision shell out to git if there is no REVISION file" do
    @config.expects(:`).with('git rev-parse HEAD').returns("bar\n")
    assert_equal "bar", @config.revision
  end
end
