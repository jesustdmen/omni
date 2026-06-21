import { Controller } from "@hotwired/stimulus"

// PB-006 — autopreenche o formulário de cliente a partir do CNPJ, chamando o
// endpoint-proxy do Omni (que consulta a BrasilAPI no servidor). Melhoria
// progressiva: sem JS, o usuário ainda digita os campos normalmente.
export default class extends Controller {
  static targets = ["cnpj", "name", "tradeName", "phone", "address", "status"]
  static values = { url: String }

  async lookup(event) {
    event.preventDefault()
    const cnpj = (this.cnpjTarget.value || "").replace(/\D/g, "")
    if (cnpj.length !== 14) { this.setStatus("CNPJ deve ter 14 dígitos."); return }

    this.setStatus("Buscando…")
    try {
      const res = await fetch(`${this.urlValue}?cnpj=${cnpj}`, {
        headers: { "Accept": "application/json" }
      })
      const data = await res.json()
      if (!res.ok) { this.setStatus(data.error || "Não foi possível consultar o CNPJ."); return }

      this.assign("nameTarget", data.name)
      this.assign("tradeNameTarget", data.trade_name)
      this.assign("phoneTarget", data.phone)
      this.assign("addressTarget", data.address)
      if (data.cnpj) this.cnpjTarget.value = data.cnpj
      this.setStatus("Dados preenchidos pela consulta de CNPJ.")
    } catch (_e) {
      this.setStatus("Falha de rede ao consultar o CNPJ.")
    }
  }

  assign(targetName, value) {
    if (value && this[`has${targetName[0].toUpperCase()}${targetName.slice(1)}`]) {
      this[targetName].value = value
    }
  }

  setStatus(message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
  }
}
