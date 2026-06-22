require "test_helper"

# PB-016a — Configurações hospeda o agendador de importação (decisão de produto).
class SettingsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret123")
    sign_in @user
  end

  test "exige autenticação" do
    sign_out @user
    get settings_path
    assert_redirected_to new_user_session_path
  end

  test "Configurações mostra o painel de agendamento (liga/desliga + intervalo)" do
    get settings_path
    assert_response :success
    assert_select "h1", "Configurações"
    assert_select ".sync-schedule form[action=?]", sync_schedule_path
    assert_select "select[name=?]", "sync_schedule[interval_minutes]"
    assert_select "input[type=checkbox][name=?]", "sync_schedule[enabled]"
  end

  test "ativar agendamento salva enabled + intervalo e volta a Configurações" do
    patch sync_schedule_path, params: { sync_schedule: { enabled: "1", interval_minutes: "30" } }
    assert_redirected_to settings_path
    s = SyncSchedule.current
    assert s.enabled
    assert_equal 30, s.interval_minutes
  end

  test "intervalo fora da allowlist é ignorado (mantém o atual)" do
    SyncSchedule.current.update!(enabled: false, interval_minutes: 60)
    patch sync_schedule_path, params: { sync_schedule: { enabled: "1", interval_minutes: "7" } }
    assert_equal 60, SyncSchedule.current.interval_minutes, "valor inválido não deve ser aplicado"
  end

  test "desativar agendamento" do
    SyncSchedule.current.update!(enabled: true, interval_minutes: 60)
    patch sync_schedule_path, params: { sync_schedule: { enabled: "0", interval_minutes: "60" } }
    assert_redirected_to settings_path
    assert_not SyncSchedule.current.enabled
  end

  test "salvar agendamento exige autenticação" do
    sign_out @user
    patch sync_schedule_path, params: { sync_schedule: { enabled: "1", interval_minutes: "60" } }
    assert_redirected_to new_user_session_path
  end

  test "estado do agendamento aparece em Configurações" do
    SyncSchedule.current.update!(enabled: true, interval_minutes: 120)
    get settings_path
    assert_select ".sync-schedule__state", /ativo/i
    assert_select ".sync-schedule__state", /2 h/
  end
end
