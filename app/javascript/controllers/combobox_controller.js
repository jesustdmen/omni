import { Controller } from "@hotwired/stimulus"

// PB-023e — combobox de multi-seleção estilo "token input".
//
// Chips dos valores escolhidos ficam DENTRO do campo; digitar filtra as opções
// num menu ("Nenhum resultado" quando vazio); × remove um chip ou limpa tudo.
// Melhoria progressiva: a fonte de verdade é um <select multiple name="key[]">
// — sem JS, ele aparece e funciona; com JS, é ocultado e a UI de token assume.
// O form envia key[]=… a partir do select em qualquer caso.
export default class extends Controller {
  static targets = ["source", "control", "chips", "input", "menu", "clear"]
  static values = { placeholder: String }

  connect() {
    this.element.classList.add("is-ready") // CSS troca select nativo → UI de token
    this.form = this.element.closest("form")
    this.boundOutside = (e) => { if (!this.element.contains(e.target)) this.close() }
    document.addEventListener("click", this.boundOutside)
    this.render()
  }

  disconnect() {
    document.removeEventListener("click", this.boundOutside)
  }

  get options() {
    return Array.from(this.sourceTarget.options)
  }

  // --- abertura / fechamento --------------------------------------------
  open() {
    this.menuTarget.hidden = false
    this.element.classList.add("is-open")
    this.renderMenu()
  }

  close() {
    this.menuTarget.hidden = true
    this.element.classList.remove("is-open")
    this.inputTarget.value = ""
  }

  toggle(event) {
    if (event.target.closest(".combo__chip-remove") || event.target.closest(".combo__clear")) return
    this.inputTarget.focus()
    this.menuTarget.hidden ? this.open() : this.renderMenu()
  }

  filter() {
    this.open()
  }

  keydown(event) {
    if (event.key === "Escape") { this.close(); return }
    // Backspace no campo vazio remove o último chip (auto-aplica).
    if (event.key === "Backspace" && this.inputTarget.value === "") {
      const selected = this.options.filter((o) => o.selected)
      const last = selected[selected.length - 1]
      if (last) this.removeValue(last.value)
    }
    // Enter escolhe a 1ª opção visível (sem submeter o form).
    if (event.key === "Enter") {
      const first = this.menuTarget.querySelector(".combo__option")
      if (first) { event.preventDefault(); this.chooseValue(first.dataset.value) }
    }
  }

  // --- seleção (auto-aplica: submete o form GET ao mudar a seleção) ------
  // Digitar apenas filtra opções localmente (filter()); só a MUDANÇA de
  // seleção — escolher, remover chip ou limpar — dispara requestSubmit().
  chooseValue(value) {
    const opt = this.options.find((o) => o.value === value)
    if (opt) opt.selected = true
    this.inputTarget.value = ""
    this.render()
    this.submitForm()
  }

  removeValue(value) {
    const opt = this.options.find((o) => o.value === value)
    if (opt) opt.selected = false
    this.render()
    this.submitForm()
  }

  clearAll(event) {
    event.stopPropagation()
    this.options.forEach((o) => { o.selected = false })
    this.render()
    this.submitForm()
  }

  // Submete o form GET (Turbo advance) sem montar URL manualmente. Não envia
  // `page` (não é campo do form) → volta à página 1 ao mudar filtros.
  submitForm() {
    if (this.form && typeof this.form.requestSubmit === "function") {
      this.form.requestSubmit()
    }
  }

  // --- render ------------------------------------------------------------
  render() {
    this.renderChips()
    this.renderMenu()
    if (this.hasClearTarget) this.clearTarget.hidden = this.options.every((o) => !o.selected)
  }

  renderChips() {
    const selected = this.options.filter((o) => o.selected)
    this.chipsTarget.replaceChildren()
    selected.forEach((o) => {
      const chip = document.createElement("span")
      chip.className = "combo__chip"
      const label = document.createElement("span")
      label.className = "combo__chip-label"
      label.textContent = o.textContent
      const remove = document.createElement("button")
      remove.type = "button"
      remove.className = "combo__chip-remove"
      remove.setAttribute("aria-label", `Remover ${o.textContent}`)
      remove.textContent = "×"
      remove.addEventListener("click", (e) => { e.stopPropagation(); this.removeValue(o.value) })
      chip.append(label, remove)
      this.chipsTarget.append(chip)
    })
    this.inputTarget.placeholder = selected.length ? "" : (this.placeholderValue || "")
  }

  renderMenu() {
    const term = this.normalize(this.inputTarget.value)
    const items = this.options.filter(
      (o) => !o.selected && (term === "" || this.normalize(o.textContent).includes(term))
    )
    this.menuTarget.replaceChildren()

    if (items.length === 0) {
      const empty = document.createElement("li")
      empty.className = "combo__empty"
      empty.textContent = "Nenhum resultado"
      this.menuTarget.append(empty)
      return
    }

    items.forEach((o) => {
      const li = document.createElement("li")
      li.className = "combo__option"
      li.dataset.value = o.value
      li.setAttribute("role", "option")
      li.textContent = o.textContent
      li.addEventListener("click", () => this.chooseValue(o.value))
      this.menuTarget.append(li)
    })
  }

  normalize(value) {
    return value.toString().toLowerCase().normalize("NFD").replace(/\p{Diacritic}/gu, "").trim()
  }
}
