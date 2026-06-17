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
    this.dispatch("updated")
  }
}
