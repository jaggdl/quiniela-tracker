import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.boundBeforeStreamRender = this.beforeStreamRender.bind(this)
    document.addEventListener("turbo:before-stream-render", this.boundBeforeStreamRender)
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.boundBeforeStreamRender)
  }

  beforeStreamRender(event) {
    if (event.target.target !== "leaderboard-content") return

    const wrapper = this.element.querySelector(".table-wrapper")
    const scrollLeft = wrapper ? wrapper.scrollLeft : 0

    if (!document.startViewTransition) {
      this.renderAndRestore(event, scrollLeft)
      return
    }

    event.preventDefault()
    const { newStream, render } = event.detail

    document.startViewTransition(() => {
      render(newStream)
      this.restoreScroll(scrollLeft)
      this.afterRender()
    })
  }

  renderAndRestore(event, scrollLeft) {
    const { newStream, render } = event.detail
    event.preventDefault()
    render(newStream)
    this.restoreScroll(scrollLeft)
    this.afterRender()
  }

  restoreScroll(scrollLeft) {
    requestAnimationFrame(() => {
      const wrapper = this.element.querySelector(".table-wrapper")
      if (wrapper) wrapper.scrollLeft = scrollLeft
    })
  }

  afterRender() {
    const select = document.getElementById("sort-select")
    if (select && select.value === "win") {
      this.#sortByWin()
    }
    this.#updateRanks()
    this.dispatch("updated")
  }

  #sortByWin() {
    const tbody = this.element.querySelector("tbody")
    if (!tbody) return

    const rows = Array.from(tbody.querySelectorAll("tr"))
    rows.sort((a, b) => {
      const winA = parseFloat(a.cells[3]?.textContent) || 0
      const winB = parseFloat(b.cells[3]?.textContent) || 0
      return winB - winA
    })
    rows.forEach(row => tbody.appendChild(row))
  }

  #updateRanks() {
    const tbody = this.element.querySelector("tbody")
    if (!tbody) return
    tbody.querySelectorAll("tr").forEach((row, i) => {
      row.cells[0].textContent = i + 1
    })
  }
}
