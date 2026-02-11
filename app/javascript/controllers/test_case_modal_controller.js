import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  connect() {
    // Use the global bootstrap object since it is loaded via CDN in the layout
    if (window.bootstrap) {
      this.bsModal = new window.bootstrap.Modal(this.modalTarget)
    } else {
      console.error("Bootstrap is not loaded")
    }
  }

  open(event) {
    if (this.bsModal) {
      this.bsModal.show()
    }
  }

  close() {
    this.bsModal.hide()
  }
}
