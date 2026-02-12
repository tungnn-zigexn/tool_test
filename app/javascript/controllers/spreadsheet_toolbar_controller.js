import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.activeCell = null
    this.savedSelection = null
    
    // Listen for focus events from editable cells
    document.addEventListener("spreadsheet-cell:focus", (e) => {
      this.activeCell = e.detail.element
      this.saveSelection()
    })
    
    document.addEventListener("spreadsheet-cell:blur", (e) => {
      if (this.activeCell === e.detail.element) {
        this.saveSelection()
      }
    })

    // Track selection changes to always have the latest range
    document.addEventListener("selectionchange", () => {
      if (this.activeCell && document.activeElement === this.activeCell) {
        this.saveSelection()
      }
    })
  }

  saveSelection() {
    const sel = window.getSelection()
    if (sel.rangeCount > 0) {
      const range = sel.getRangeAt(0)
      if (this.activeCell && this.activeCell.contains(range.commonAncestorContainer)) {
        this.savedSelection = range.cloneRange()
      }
    }
  }

  restoreSelection() {
    if (this.savedSelection && this.activeCell) {
      const sel = window.getSelection()
      sel.removeAllRanges()
      sel.addRange(this.savedSelection)
      this.activeCell.focus()
    }
  }

  preventFocusLoss(event) {
    // Prevent the default behavior of mousedown which is focus loss
    event.preventDefault()
    if (this.activeCell) this.restoreSelection()
  }

  format(event) {
    event.preventDefault()
    if (!this.activeCell) return

    const command = event.currentTarget.dataset.command
    const value = event.currentTarget.dataset.value || null
    
    this.activeCell.dataset.formatting = "true"
    this.restoreSelection()

    if (this.activeCell.contentEditable === "true") {
      document.execCommand(command, false, value)
      
      // Briefly maintain state before allowing potential re-renders
      setTimeout(() => {
        this.saveSelection()
        if (this.activeCell) delete this.activeCell.dataset.formatting
      }, 50)
    }
  }
}
