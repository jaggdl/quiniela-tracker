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

    if (!document.startViewTransition) return

    event.preventDefault()
    const { newStream, render } = event.detail

    document.startViewTransition(() => {
      render(newStream)
      this.afterRender()
    })
  }

  afterRender() {
    this.dispatch("updated")
  }
}
