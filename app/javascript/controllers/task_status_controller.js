import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  change(event) {
    event.preventDefault()
    const newStatus = event.currentTarget.dataset.taskStatusValue
    const url = event.currentTarget.dataset.taskStatusUrlValue

    fetch(url, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        "Accept": "text/html"
      },
      body: JSON.stringify({ task: { status: newStatus } })
    })
    .then(response => {
      if (response.ok) {
        // Reload the page to reflect the new status
        window.location.reload()
      } else {
        alert("Failed to update status. Please try again.")
      }
    })
    .catch(error => {
      console.error("Error updating status:", error)
      alert("An error occurred while updating the status.")
    })
  }
}
