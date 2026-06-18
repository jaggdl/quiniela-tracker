import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const id = document.body.dataset.currentParticipantId
    if (!id) return

    const row = this.element.querySelector(`tbody tr[data-participant-id="${id}"]`)
    if (!row) return

    const tbody = this.element.querySelector("tbody")
    const existing = tbody.querySelector("tr.current-user")
    if (existing) existing.remove()

    const clone = row.cloneNode(true)
    clone.classList.add("current-user")
    clone.removeAttribute("data-favorites-target")
    clone.classList.remove("favorited")
    const heart = clone.querySelector(".fav-heart")
    if (heart) heart.remove()

    const theadRow = this.element.querySelector("thead tr")
    const headerHeight = theadRow ? theadRow.offsetHeight : 28

    clone.querySelectorAll("td").forEach(td => {
      td.style.position = "sticky"
      td.style.top = `${headerHeight}px`
    })

    clone.querySelectorAll("td.col-rank, td.col-name, td.col-pts, td.col-win").forEach(td => {
      td.style.zIndex = "2"
    })

    tbody.insertBefore(clone, tbody.firstChild)
  }
}
