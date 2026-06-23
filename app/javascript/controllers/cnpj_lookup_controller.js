import { Controller } from "@hotwired/stimulus"

// PB-006 — autopreenche o formulário de cliente a partir do CNPJ.
//
// A consulta vai DIRETO do navegador para a BrasilAPI (como no RepoA), usando o IP
// do próprio usuário — evita o rate-limit por IP que afeta a saída do servidor/
// container (ADR-022, addendum 2026-06-22). É uma API pública, sem chave/segredo.
// Host fixo (allowlist no cliente); só os 14 dígitos vão na URL. Melhoria
// progressiva: sem JS, o usuário ainda preenche os campos manualmente.
export default class extends Controller {
  static targets = ["cnpj", "name", "tradeName", "phone", "address", "status"]

  // Allowlist: host fixo; nunca montado a partir de input do usuário.
  static API = "https://brasilapi.com.br/api/cnpj/v1/"

  async lookup(event) {
    event.preventDefault()
    const digits = (this.cnpjTarget.value || "").replace(/\D/g, "") // máscara → só dígitos
    if (digits.length !== 14) { this.setStatus("CNPJ deve ter 14 dígitos."); return }

    this.setStatus("Buscando…")
    try {
      const res = await fetch(`${this.constructor.API}${digits}`, {
        headers: { "Accept": "application/json" }
      })

      if (res.status === 404) { this.setStatus("CNPJ não encontrado."); return }
      if (res.status === 429) { this.setStatus("Limite de consultas de CNPJ atingido. Aguarde cerca de 1 minuto e tente novamente."); return }
      if (!res.ok) { this.setStatus("Serviço de CNPJ indisponível no momento."); return }

      const json = await res.json()
      this.assign("name", this.up(json.razao_social))
      this.assign("tradeName", this.up(json.nome_fantasia))
      this.assign("phone", json.ddd_telefone_1)
      this.assign("address", this.buildAddress(json))
      this.cnpjTarget.value = digits // normaliza o campo para dígitos
      this.setStatus("Dados preenchidos pela consulta de CNPJ.")
    } catch (_e) {
      this.setStatus("Falha de rede ao consultar o CNPJ.")
    }
  }

  // Espelha Cnpj::Lookup#build_address (logradouro, nº - bairro - município/UF - CEP), upcase.
  buildAddress(j) {
    const head = [j.logradouro, j.numero].filter(Boolean).join(", ")
    const city = [j.municipio, j.uf].filter(Boolean).join("/")
    const cep = j.cep ? `CEP: ${j.cep}` : null
    const parts = [head, j.bairro, city, cep].filter((p) => p && String(p).trim() !== "")
    const out = parts.join(" - ").toUpperCase()
    return out || null
  }

  up(v) { return v ? String(v).toUpperCase() : null }

  assign(targetName, value) {
    const has = `has${targetName[0].toUpperCase()}${targetName.slice(1)}Target`
    if (value && this[has]) this[`${targetName}Target`].value = value
  }

  setStatus(message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
  }
}
