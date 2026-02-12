import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  update(event) {
    event.preventDefault()
    const { value, field, testCaseId, projectId, taskId } = event.currentTarget.dataset
    const url = `/projects/${projectId}/tasks/${taskId}/test_cases/${testCaseId}`
    
    const formData = new FormData()
    formData.append(`test_case[${field}]`, value)
    
    fetch(url, {
      method: "PATCH",
      body: formData,
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        "Accept": "text/vnd.turbo-stream.html"
      }
    })
    .then(response => response.text())
    .then(html => {
      Turbo.renderStreamMessage(html)
    })
    .catch(error => {
      console.error("Error updating test case:", error)
      alert("Failed to update test case. Please try again.")
    })
  }
}
