import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toggle-modal"
export default class extends Controller {
  static values = {
    target: String
  }

  toggle() {
    const modal = document.getElementById(this.targetValue)
    if (modal) {
      modal.classList.toggle('hidden')
      if (!modal.classList.contains('hidden')) {
        document.body.style.overflow = 'hidden'
      } else {
        document.body.style.overflow = 'auto'
      }
    }
  }
}


