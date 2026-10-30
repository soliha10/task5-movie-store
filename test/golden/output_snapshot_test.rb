require "test_helper"
require_relative "golden_output"

class OutputSnapshotTest < ActiveSupport::TestCase
  test "generated movies and trailers match the recorded snapshot" do
    expected = JSON.parse(File.read(GoldenOutput::FIXTURE_PATH))
    actual = GoldenOutput.generate

    assert_equal expected.keys, actual.keys
    expected.each_key { |key| assert_equal expected[key], actual[key], "snapshot changed for #{key}" }
  end
end
