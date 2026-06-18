import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.lastHiddenAt = null
    this.boundVisibilityChange = this.onVisibilityChange.bind(this)
    document.addEventListener("visibilitychange", this.boundVisibilityChange)

    const wrapper = this.element.closest(".table-wrapper")
    if (wrapper && wrapper.scrollLeft === 0 && wrapper.scrollTop === 0) {
      this.scrollToLatestResult()
    }
  }

  disconnect() {
    document.removeEventListener("visibilitychange", this.boundVisibilityChange)
  }

  onVisibilityChange() {
    if (document.hidden) {
      this.lastHiddenAt = Date.now()
    } else if (this.lastHiddenAt && (Date.now() - this.lastHiddenAt) > 5 * 60 * 1000) {
      this.refreshTable()
      this.lastHiddenAt = null
    }
  }

  refreshTable() {
    const frame = document.getElementById("leaderboard-content-frame")
    if (frame) frame.reload()
  }

  scrollToLatestResult() {
    const wrapper = this.element.closest(".table-wrapper")
    if (!wrapper) return

    const headers = wrapper.querySelectorAll("th.col-match")
    let lastResult = null
    headers.forEach(th => {
      const result = th.querySelector(".match-result")
      if (result && /\d+\s*-\s*\d+/.test(result.textContent)) {
        lastResult = th
      }
    })

    if (lastResult) {
      const wrapperRect = wrapper.getBoundingClientRect()
      const thRect = lastResult.getBoundingClientRect()
      wrapper.scrollLeft += thRect.right - wrapperRect.right + 8
    }
  }
}
