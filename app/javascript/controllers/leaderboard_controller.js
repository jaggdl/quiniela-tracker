import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.boundBeforeStreamRender = this.beforeStreamRender.bind(this)
    document.addEventListener("turbo:before-stream-render", this.boundBeforeStreamRender)
    this.scrollToLatestResult()
  }

  scrollToLatestResult() {
    const wrapper = this.element.querySelector(".table-wrapper")
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
