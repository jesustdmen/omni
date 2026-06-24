require "test_helper"

# PB-019b — Contrato: validações + regra de sobreposição (ADR-025).
class ContractTest < ActiveSupport::TestCase
  setup do
    @provider = ProviderCompany.create!(name: "Presta A")
    @client = Client.create!(name: "Cliente A")
    @project = @client.projects.create!(name: "Proj A1", status: "planning")
  end

  def build_contract(**attrs)
    Contract.new({ provider_company: @provider, client: @client,
                   hourly_rate: 100, status: "active", start_date: Date.new(2026, 1, 1) }.merge(attrs))
  end

  # --- Validações básicas ---
  test "válido com campos mínimos" do
    assert build_contract.valid?
  end

  test "provider_company obrigatório" do
    c = build_contract(provider_company: nil)
    assert_not c.valid?
    assert c.errors[:provider_company].any?
  end

  test "client obrigatório" do
    c = build_contract(client: nil)
    assert_not c.valid?
    assert c.errors[:client].any?
  end

  test "start_date obrigatório" do
    c = build_contract(start_date: nil)
    assert_not c.valid?
    assert c.errors[:start_date].any?
  end

  test "hourly_rate obrigatório e maior que zero" do
    assert_not build_contract(hourly_rate: nil).valid?
    assert_not build_contract(hourly_rate: 0).valid?
    assert_not build_contract(hourly_rate: -5).valid?
    assert build_contract(hourly_rate: 0.5).valid?
  end

  test "end_date não pode ser anterior a start_date" do
    c = build_contract(start_date: Date.new(2026, 5, 1), end_date: Date.new(2026, 1, 1))
    assert_not c.valid?
    assert c.errors[:end_date].any?
    assert build_contract(start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 1, 1)).valid? # igual OK
  end

  test "status deve estar no enum fixo" do
    assert_not build_contract(status: "fantasia").valid?
    Contract::STATUSES.each { |s| assert build_contract(status: s, start_date: Date.new(2030, 1, 1)).valid?, s }
  end

  test "modalidade só aceita hourly" do
    assert_not build_contract(modality: "monthly").valid?
    assert build_contract(modality: "hourly").valid?
  end

  test "projeto deve pertencer ao mesmo cliente" do
    other_client = Client.create!(name: "Outro")
    other_project = other_client.projects.create!(name: "PX", status: "planning")
    c = build_contract(project: other_project)
    assert_not c.valid?
    assert c.errors[:project].any?
  end

  test "status_label PT-BR" do
    assert_equal "Rascunho", build_contract(status: "draft").status_label
    assert_equal "Ativo", build_contract(status: "active").status_label
    assert_equal "Suspenso", build_contract(status: "suspended").status_label
    assert_equal "Encerrado", build_contract(status: "ended").status_label
  end

  # --- Sobreposição (ADR-025) ---
  test "bloqueia dois contratos GERAIS sobrepostos (mesma prestadora+cliente)" do
    build_contract(start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 6, 30)).save!
    dup = build_contract(start_date: Date.new(2026, 6, 1), end_date: Date.new(2026, 12, 31))
    assert_not dup.valid?
    assert dup.errors[:base].any?
  end

  test "permite contratos gerais em períodos distintos (sem sobreposição)" do
    build_contract(start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 6, 30)).save!
    seq = build_contract(start_date: Date.new(2026, 7, 1))
    assert seq.valid?, seq.errors.full_messages.to_sentence
  end

  test "vigência aberta (end nil) bloqueia novo contrato geral que comece depois" do
    build_contract(start_date: Date.new(2026, 1, 1), end_date: nil).save!
    later = build_contract(start_date: Date.new(2026, 12, 1))
    assert_not later.valid?, "início posterior ainda cai dentro da vigência aberta"
  end

  test "PERMITE contrato geral + contrato de projeto no mesmo período" do
    build_contract(start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 6, 30)).save!
    proj = build_contract(project: @project, start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 6, 30))
    assert proj.valid?, proj.errors.full_messages.to_sentence
  end

  test "bloqueia dois contratos do MESMO projeto sobrepostos" do
    build_contract(project: @project, start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 6, 30)).save!
    dup = build_contract(project: @project, start_date: Date.new(2026, 3, 1))
    assert_not dup.valid?
    assert dup.errors[:base].any?
  end

  test "contrato ENCERRADO não bloqueia novo no mesmo período (histórico)" do
    build_contract(status: "ended", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 6, 30)).save!
    novo = build_contract(status: "active", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 6, 30))
    assert novo.valid?, "um contrato encerrado não deve ocupar o período"
  end

  test "editar o próprio contrato não acusa sobreposição consigo mesmo" do
    c = build_contract(start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 6, 30))
    c.save!
    c.hourly_rate = 200
    assert c.valid?, c.errors.full_messages.to_sentence
  end

  # --- Integridade de exclusão (FK) ---
  test "prestadora com contrato não é excluível (restrict)" do
    build_contract.save!
    assert_not @provider.destroy
    assert @provider.errors.present?
  end
end
