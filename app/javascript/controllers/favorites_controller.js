import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.render()

    this.observer = new MutationObserver(() => this.debouncedRender())
    this.observer.observe(this.element, { childList: true, subtree: true })
    this.renderTimer = null
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
    if (this.renderTimer) clearTimeout(this.renderTimer)
  }

  debouncedRender() {
    if (this.renderTimer) clearTimeout(this.renderTimer)
    this.renderTimer = setTimeout(() => this.render(), 50)
  }

  render() {
    const favorites = this.getFavorites()
    const filterActive = this.getFilterCookie() === "1"

    this.updateFilterButton(filterActive, favorites.length === 0)
    this.rows().forEach(row => {
      const id = row.dataset.participantId
      const heart = row.querySelector(".fav-heart")
      const isFavorite = favorites.includes(id)

      row.classList.toggle("favorited", isFavorite)
      if (heart) heart.textContent = isFavorite ? "♥" : "♡"

      const show = !filterActive || isFavorite || row.dataset.leader
      row.style.display = show ? "" : "none"
    })
  }

  toggle(event) {
    const participantId = event.currentTarget.dataset.participantId
    const favorites = this.getFavorites()
    if (favorites.includes(participantId)) {
      this.setFavorites(favorites.filter(id => id !== participantId))
    } else {
      this.setFavorites([...favorites, participantId])
    }
    this.render()
  }

  toggleFilter() {
    const active = this.getFilterCookie() !== "1"
    document.cookie = `favorites-filter=${active ? "1" : "0"}; path=/; max-age=${60 * 60 * 24 * 365}`
    this.render()
  }

  updateFilterButton(active, empty) {
    const btn = this.element.querySelector(".fav-filter-btn")
    if (!btn) return
    btn.textContent = active ? "Mostrar todos" : "Solo favoritos"
    btn.disabled = empty && !active
    btn.style.opacity = (empty && !active) ? "0.5" : ""
  }

  rows() {
    return Array.from(this.element.querySelectorAll("tr[data-favorites-target='row']"))
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
