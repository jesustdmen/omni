import { Controller } from "@hotwired/stimulus"

// PB-023e — coordenação da barra de filtros no modo JS.
//
// Marca o form como "JS ativo" (o CSS oculta o botão "Filtrar", que segue como
// fallback sem JS) e auto-submete ao trocar o "por página". A multi-seleção
// (chips) auto-submete pelo próprio combobox_controller. A busca textual segue
// submetendo no Enter (comportamento nativo do form).
export default class extends Controller {
  connect() {
    this.element.classList.add("filter-bar--js")
  }

  submit() {
    this.element.requestSubmit()
  }
}
