import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="modal"
export default class extends Controller {
  static targets = ["content"]

  connect() {
    // Close modal when clicking outside
    this.element.addEventListener('click', (e) => {
      if (e.target === this.element) {
        this.close()
      }
    })
  }

  open() {
    this.element.classList.remove('hidden')
    document.body.style.overflow = 'hidden'
  }

  close() {
    this.element.classList.add('hidden')
    document.body.style.overflow = 'auto'
  }

  toggle() {
    if (this.element.classList.contains('hidden')) {
      this.open()
    } else {
      this.close()
    }
  }

  stopPropagation(event) {
    event.stopPropagation()
  }
}


