import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.boundScroll = this.onScroll.bind(this)
    this.element.addEventListener("scroll", this.boundScroll)
    this.onScroll()
  }

  disconnect() {
    this.element.removeEventListener("scroll", this.boundScroll)
  }

  onScroll() {
    this.element.classList.toggle("scrolled", this.element.scrollLeft > 0)
  }
}
