require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  # F5.1.3 — safe_basename: nome de arquivo seguro (sem path/PII) para telas.
  test "safe_basename retorna só o nome do arquivo" do
    assert_equal "sessions.jsonl", safe_basename("/normalized/sessions.jsonl")
    assert_equal "s1.jsonl", safe_basename("/tmp/s20260618-8-x.jsonl".sub("s20260618-8-x", "s1"))
    assert_equal "x.jsonl", safe_basename("/home/jesus/x.jsonl")
    assert_equal "x.jsonl", safe_basename("C:\\Users\\Jesus\\x.jsonl")
    assert_equal "x.jsonl", safe_basename("file:///c:/Users/Jesus/x.jsonl")
    assert_equal "sessions.jsonl", safe_basename("sessions.jsonl")
  end

  test "safe_basename trata vazio/nil" do
    assert_equal "—", safe_basename(nil)
    assert_equal "—", safe_basename("")
  end

  test "safe_basename nunca expõe separadores de path nem PII de host" do
    %w[/normalized/sessions.jsonl /home/jesus/x.jsonl /tmp/s.jsonl].each do |p|
      out = safe_basename(p)
      assert_not_includes out, "/"
      assert_not_includes out, "\\"
    end
    out = safe_basename("file:///c:/Users/Jesus/x.jsonl")
    assert_not_includes out, "Users"
    assert_not_includes out, "Jesus"
    assert_not_includes out, "file:"
  end
end
