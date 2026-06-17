require "test_helper"

class SyncRunTest < ActiveSupport::TestCase
  test "status default é ok" do
    run = SyncRun.create!
    assert_equal "ok", run.status
  end

  test "status aceita somente ok/partial/error" do
    assert_not SyncRun.new(status: "bogus").valid?
    %w[ok partial error].each { |s| assert SyncRun.new(status: s).valid?, "#{s} deveria ser válido" }
  end

  test "contadores default 0" do
    run = SyncRun.create!
    assert_equal 0, run.lines_processed
    assert_equal 0, run.imported
    assert_equal 0, run.updated
    assert_equal 0, run.skipped
    assert_equal 0, run.error_lines
  end

  test "destrói itens em cascata" do
    run = SyncRun.create!
    run.items.create!(status: "error", line_number: 1, reason: "x")
    assert_difference "SyncRunItem.count", -1 do
      run.destroy
    end
  end
end
