import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row"]

  connect() {
    this.applyFavorites()
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
  }

  getFavorites() {
    const cookie = document.cookie.split("; ").find(r => r.startsWith("favorites="))
    return cookie ? cookie.split("=")[1].split(",") : []
  }

  setFavorites(ids) {
    document.cookie = `favorites=${ids.join(",")}; path=/; max-age=${60 * 60 * 24 * 365}`
  }
}
