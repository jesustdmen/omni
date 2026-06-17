require "test_helper"

class TimeEntryPolicyTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret123")
    @client = Client.create!(name: "ACME")
    @task = @client.tasks.create!(title: "T", type: "support")
    @entry = @task.time_entries.create!(start_time: Time.current, date: Date.current, duration: 10)
  end

  test "usuário autenticado acessa" do
    assert TimeEntryPolicy.new(@user, @entry).show?
    assert TimeEntryPolicy.new(@user, @entry).create?
    assert TimeEntryPolicy.new(@user, @entry).update?
    assert TimeEntryPolicy.new(@user, @entry).destroy?
  end

  test "anônimo não acessa" do
    assert_not TimeEntryPolicy.new(nil, @entry).show?
    assert_not TimeEntryPolicy.new(nil, @entry).create?
  end

  test "scope: autenticado vê, anônimo não" do
    assert_equal 1, TimeEntryPolicy::Scope.new(@user, TimeEntry).resolve.count
    assert_equal 0, TimeEntryPolicy::Scope.new(nil, TimeEntry).resolve.count
  end
end
