import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row"]

  connect() {
    this.applyFavorites()
    this.applyFilter()
    this.updateFilterButton()
  }

  toggle(event) {
    const heart = event.currentTarget
    const participantId = heart.dataset.participantId
    const favorites = this.getFavorites()

    if (favorites.includes(participantId)) {
      this.setFavorites(favorites.filter(id => id !== participantId))
    } else {
      this.setFavorites([...favorites, participantId])
    }

    this.applyFavorites()
    this.updateFilterButton()
  }

  toggleFilter() {
    const active = this.getFilterCookie() !== "1"
    document.cookie = `favorites-filter=${active ? "1" : "0"}; path=/; max-age=${60 * 60 * 24 * 365}`
    this.applyFilter()
  }

  applyFilter() {
    const active = this.getFilterCookie() === "1"
    const btn = this.element.querySelector(".fav-filter-btn")
    if (btn) btn.textContent = active ? "Mostrar todos" : "Solo favoritos"

    const favorites = this.getFavorites()
    this.rowTargets.forEach(row => {
      const id = row.dataset.participantId
      const show = !active || favorites.includes(id) || row.dataset.leader
      row.style.display = show ? "" : "none"
    })
  }

  updateFilterButton() {
    const btn = this.element.querySelector(".fav-filter-btn")
    if (!btn) return
    const empty = this.getFavorites().length === 0
    const active = this.getFilterCookie() === "1"
    btn.disabled = empty && !active
    btn.style.opacity = (empty && !active) ? "0.5" : ""
  }

  applyFavorites() {
    const favorites = this.getFavorites()
    this.rowTargets.forEach(row => {
      const id = row.dataset.participantId
      const heart = row.querySelector(".fav-heart")
      if (favorites.includes(id)) {
        row.classList.add("favorited")
        if (heart) heart.textContent = "♥"
      } else {
        row.classList.remove("favorited")
        if (heart) heart.textContent = "♡"
      }
    })
    this.applyFilter()
  }

  getFavorites() {
    const cookie = document.cookie.split("; ").find(r => r.startsWith("favorites="))
    return cookie ? cookie.split("=")[1].split(",") : []
  }

  setFavorites(ids) {
    document.cookie = `favorites=${ids.join(",")}; path=/; max-age=${60 * 60 * 24 * 365}`
  }

  getFilterCookie() {
    const cookie = document.cookie.split("; ").find(r => r.startsWith("favorites-filter="))
    return cookie ? cookie.split("=")[1] : "0"
  }
}
