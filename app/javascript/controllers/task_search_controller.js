import { Controller } from "@hotwired/stimulus"

// Controls live search on the tasks index page.
// Submits the form on keydown/typing with a small debounce.
export default class extends Controller {
  static targets = ["input", "form"]

  connect() {
    this.timeout = null

    // When page reloads after search, auto-focus back to the search input
    if (this.hasInputTarget) {
      setTimeout(() => {
        this.inputTarget.focus()

        const value = this.inputTarget.value
        this.inputTarget.setSelectionRange?.(value.length, value.length)
      }, 0)
    }
  }

  keydown() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      if (this.hasFormTarget) {
        this.formTarget.requestSubmit()
      } else {
        this.element.closest("form")?.requestSubmit()
      }
    }, 300)
  }

  submit() {
    if (this.hasFormTarget) {
      this.formTarget.requestSubmit()
    } else {
      this.element.closest("form")?.requestSubmit()
    }
  }
}
