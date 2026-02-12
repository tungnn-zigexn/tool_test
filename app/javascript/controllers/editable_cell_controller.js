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
    input.className = "form-control p-1 bg-white border-primary fs-spreadsheet"
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

    input.addEventListener("focus", () => {
      document.dispatchEvent(new CustomEvent("spreadsheet-cell:focus", { detail: { element: input } }))
    })

    input.addEventListener("blur", () => {
      document.dispatchEvent(new CustomEvent("spreadsheet-cell:blur", { detail: { element: input } }))
      save()
    })

    input.addEventListener("paste", (e) => {
      // Basic auto-link on paste
      setTimeout(() => {
        const text = input.innerHTML
        const urlPattern = /(?<!["'=])(https?:\/\/[^\s<]+)/g
        if (urlPattern.test(text)) {
          // We can't easily auto-link without breaking HTML during editing
          // but we can at least ensure we don't break things.
          // For now, linkification will happen on the server when rendering.
        }
      }, 0)
    })

    input.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault()
        input.blur()
      }
      if (e.key === "Escape") {
        this.finishEdit(input, target)
      }
    })

    // Manually trigger focus dispatch since it might already be focused
    document.dispatchEvent(new CustomEvent("spreadsheet-cell:focus", { detail: { element: input } }))
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
      // Direct update to test step content via shallow route
      url = `/test_step_contents/${contentId}`
      params = { test_step_content: { [field]: value } }
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
        // Only update innerHTML if we are NOT currently formatting or actively selected
        // This prevents the linkified version from destroying active selection/formatting
        const toolbar = document.querySelector('.spreadsheet-toolbar')
        const isToolbarActive = toolbar && toolbar.contains(document.activeElement)
        const isSelfActive = document.activeElement === display
        
        if (!isSelfActive && !isToolbarActive && !display.dataset.formatting) {
          display.innerHTML = data.formatted_value || value
        }
        
        // Optional: show a small success indicator
        display.classList.add("text-success")
        setTimeout(() => display.classList.remove("text-success"), 1000)
      }
    })
    .catch(error => {
      console.error("Error saving change:", error)
      display.classList.add("text-danger")
      setTimeout(() => display.classList.remove("text-danger"), 2000)
    })
  }
}
