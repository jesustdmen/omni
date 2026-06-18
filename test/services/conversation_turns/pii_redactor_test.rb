require "test_helper"

class ConversationTurns::PiiRedactorTest < ActiveSupport::TestCase
  R = ConversationTurns::PiiRedactor

  test "redige e-mail" do
    assert_equal "fale com <EMAIL> hoje", R.call("fale com joao.silva@example.com hoje")
  end

  test "redige path Unix/macOS" do
    assert_equal "/Users/<USER>/proj/x.rb", R.call("/Users/jesus/proj/x.rb")
    assert_equal "/home/<USER>/.config", R.call("/home/maria/.config")
  end

  test "redige path Windows (\\ e /)" do
    assert_equal "C:\\Users\\<USER>\\app", R.call("C:\\Users\\Jesus\\app")
    assert_equal "C:/Users/<USER>/app", R.call("C:/Users/Jesus/app")
  end

  test "redige Bearer" do
    assert_equal "Authorization: Bearer <SECRET>", R.call("Authorization: Bearer eyJhbGciOi.J9.sig")
  end

  test "redige token/api_key/secret/password em querystring e JSON" do
    assert_equal "url?token=<SECRET>", R.call("url?token=abc123xyz")
    assert_equal "api_key=<SECRET>", R.call("api_key=AKIA1234567890")
    assert_equal %(secret=<SECRET>), R.call("secret=s3nh4")
    assert_equal %(password=<SECRET>), R.call("password=p@ssw0rd")
    # JSON-like (aspas preservadas em volta do valor)
    assert_equal %({"token": "<SECRET>"}), R.call(%({"token": "abcDEF123"}))
  end

  test "password com e-mail vira SECRET (não vaza o e-mail)" do
    out = R.call("password=foo@bar.com")
    assert_equal "password=<SECRET>", out
    assert_not_includes out, "foo@bar.com"
  end

  test "idempotente: rodar duas vezes não degrada marcadores" do
    inputs = [
      "joao@example.com",
      "/Users/jesus/x",
      "C:\\Users\\Jesus\\x",
      "Bearer eyJabc.def",
      "token=abc123",
      %({"password": "x"})
    ]
    inputs.each do |i|
      once = R.call(i)
      twice = R.call(once)
      assert_equal once, twice, "não idempotente para: #{i.inspect}"
    end
    # marcadores não são re-redigidos
    assert_equal "<EMAIL>", R.call("<EMAIL>")
    assert_equal "/Users/<USER>/x", R.call("/Users/<USER>/x")
    assert_equal "Bearer <SECRET>", R.call("Bearer <SECRET>")
  end

  test "string sem PII permanece inalterada; nil preservado" do
    assert_equal "texto normal sem segredo", R.call("texto normal sem segredo")
    assert_nil R.call(nil)
    assert_equal "", R.call("")
  end
end
