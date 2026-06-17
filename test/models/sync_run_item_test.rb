require "test_helper"

class SyncRunItemTest < ActiveSupport::TestCase
  setup do
    @run = SyncRun.create!
  end

  test "pertence a um sync_run" do
    item = SyncRunItem.new(status: "error")
    assert_not item.valid?
    assert item.errors[:sync_run].any?
  end

  test "status aceita somente error/skipped" do
    assert_not SyncRunItem.new(sync_run: @run, status: "bogus").valid?
    %w[error skipped].each do |s|
      assert SyncRunItem.new(sync_run: @run, status: s).valid?, "#{s} deveria ser válido"
    end
  end
end
