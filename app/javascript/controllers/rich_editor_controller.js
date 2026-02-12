import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "hidden"]

  connect() {
    this.syncContent()
  }

  // Called on input event of the contenteditable div
  sync(event) {
    this.hiddenTarget.value = this.inputTarget.innerHTML
  }

  // Initial sync from hidden field to contenteditable (if needed)
  syncContent() {
    if (this.hiddenTarget.value && !this.inputTarget.innerHTML) {
      this.inputTarget.innerHTML = this.hiddenTarget.value
    }
  }

  onFocus() {
    document.dispatchEvent(new CustomEvent("spreadsheet-cell:focus", { 
      detail: { element: this.inputTarget } 
    }))
  }

  onBlur() {
    document.dispatchEvent(new CustomEvent("spreadsheet-cell:blur", { 
      detail: { element: this.inputTarget } 
    }))
    this.sync()
  }

  // Handle paste to clean up styles if necessary
  onPaste(event) {
    // Optionally clean up here, though we largely want to preserve formatting
  }
}
