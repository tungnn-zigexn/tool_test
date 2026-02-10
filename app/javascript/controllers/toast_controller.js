import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toast"
export default class extends Controller {
  connect() {
    // Wait for Bootstrap to be loaded
    this.initializeToast()
  }

  initializeToast() {
    // Bootstrap is loaded via CDN in the layout
    if (typeof bootstrap !== 'undefined' && bootstrap.Toast) {
      const toast = new bootstrap.Toast(this.element, {
        autohide: true,
        delay: 5000 // 5 seconds
      })
      
      // Show the toast
      toast.show()

      // Remove element after it's hidden
      this.element.addEventListener('hidden.bs.toast', () => {
        this.element.remove()
      })
    } else {
      // Fallback: retry after a short delay
      setTimeout(() => this.initializeToast(), 100)
    }
  }
}

