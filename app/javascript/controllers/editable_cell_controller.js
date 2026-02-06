import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display"]

  edit(event) {
    if (this.editing) return
    this.editing = true
    
    const target = event.currentTarget
    const field = target.dataset.field
    const contentId = target.dataset.contentId // If editing test_step_content
    const originalContent = target.innerHTML.trim()
    
    const input = document.createElement("div")
    input.contentEditable = true
    input.className = "form-control p-1 bg-white border-primary"
    input.style.minWidth = "100px"
    input.style.minHeight = "40px"
    input.innerHTML = originalContent
    
    target.style.display = "none"
    target.parentNode.insertBefore(input, target)
    input.focus()
    
    // Select all text
    const range = document.createRange()
    range.selectNodeContents(input)
    const sel = window.getSelection()
    sel.removeAllRanges()
    sel.addRange(range)

    const save = () => {
      const newContent = input.innerHTML.trim()
      if (newContent !== originalContent) {
        this.saveChange(field, contentId, newContent, target)
      }
      this.finishEdit(input, target)
    }

    input.addEventListener("blur", save)
    input.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault()
        input.blur()
      }
      if (e.key === "Escape") {
        this.finishEdit(input, target)
      }
    })
  }

  finishEdit(input, display) {
    input.remove()
    display.style.display = "block"
    this.editing = false
  }

  saveChange(field, contentId, value, display) {
    const { projectId, taskId, testCaseId } = this.element.dataset
    let url = `/projects/${projectId}/tasks/${taskId}/test_cases/${testCaseId}`
    let params = { test_case: {} }

    if (contentId) {
      // Logic for editing test step content could be here, or a separate endpoint
      // For now, let's assume we update via test_case nested attributes or direct content update
      url = `/projects/${projectId}/tasks/${taskId}/test_cases/${testCaseId}/test_steps/0` // Placeholder
      // This part needs careful controller routing. Let's stick to title for now.
    } else {
      params.test_case[field] = value
    }

    fetch(url, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        "Accept": "application/json"
      },
      body: JSON.stringify(params)
    })
    .then(response => response.json())
    .then(data => {
      if (data.id) {
        display.innerHTML = value
      }
    })
  }
}
