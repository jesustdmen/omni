require "test_helper"

class WorkspaceMapTest < ActiveSupport::TestCase
  test "workspace_hash obrigatório e único" do
    assert_not WorkspaceMap.new(workspace_hash: nil).valid?
    WorkspaceMap.create!(workspace_hash: "ws-1", folder: "/tmp/x")
    assert_not WorkspaceMap.new(workspace_hash: "ws-1").valid?
  end

  test "scope orphan retorna apenas folder nil" do
    known = WorkspaceMap.create!(workspace_hash: "ws-known", folder: "/tmp/known")
    orphan = WorkspaceMap.create!(workspace_hash: "ws-orphan", folder: nil)

    assert_includes WorkspaceMap.orphan, orphan
    assert_not_includes WorkspaceMap.orphan, known
  end
end
