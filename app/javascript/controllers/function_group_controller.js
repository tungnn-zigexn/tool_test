import { Controller } from "@hotwired/stimulus"

// Manages merge/split of test case function groups.
// Operates purely on the client side using the existing PATCH endpoint.
export default class extends Controller {
  static values = {
    testCaseId: Number,
    projectId: Number,
    taskId: Number
  }

  // Merge: copy the title from the nearest visible function cell above, save via PATCH, then reload
  merge(event) {
    event.preventDefault()

    const currentRow = this.element.closest("tr.test-case-row")
    if (!currentRow) return

    // Walk backward through ALL previous sibling rows until we find one
    // that has a visible function/title cell (handles rowspan-hidden rows)
    let prevRow = currentRow.previousElementSibling
    let prevTitleEl = null

    while (prevRow) {
      if (prevRow.classList.contains("test-case-row")) {
        prevTitleEl = prevRow.querySelector("[data-field='title']")
        if (prevTitleEl) break
      }
      prevRow = prevRow.previousElementSibling
    }

    if (!prevTitleEl) {
      alert("No row above to merge with.")
      return
    }

    const prevTitle = prevTitleEl.textContent.trim()
    if (!prevTitle) {
      alert("The row above has no function name.")
      return
    }

    if (!confirm(`Merge this test case into function: "${prevTitle}"?`)) return

    this._saveTitleAndReload(prevTitle)
  }

  // Split: prompt user for a new unique title, save via PATCH (WITHOUT syncing siblings), then reload
  split(event) {
    event.preventDefault()

    const titleEl = this.element.closest("td")?.querySelector("[data-field='title']")
    const currentTitle = titleEl ? titleEl.textContent.trim() : ""

    const newTitle = prompt("Enter a new function name for this test case:", currentTitle)
    if (newTitle === null) return // cancelled
    if (newTitle.trim() === "") {
      alert("Function name cannot be empty.")
      return
    }
    if (newTitle.trim() === currentTitle) {
      alert("Please enter a different function name to split.")
      return
    }

    this._saveTitleAndReload(newTitle.trim(), { skipSync: true })
  }

  _saveTitleAndReload(newTitle, options = {}) {
    const url = `/projects/${this.projectIdValue}/tasks/${this.taskIdValue}/test_cases/${this.testCaseIdValue}`

    const body = { test_case: { title: newTitle } }
    if (options.skipSync) {
      body.skip_title_sync = true
    }

    fetch(url, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        "Accept": "application/json"
      },
      body: JSON.stringify(body)
    })
    .then(response => {
      if (response.ok) {
        // Reload the page to re-render the table with updated rowspans
        window.location.reload()
      } else {
        return response.json().then(data => {
          alert("Failed to update: " + (data.errors || []).join(", "))
        })
      }
    })
    .catch(error => {
      console.error("Error:", error)
      alert("An error occurred while saving.")
    })
  }
}
