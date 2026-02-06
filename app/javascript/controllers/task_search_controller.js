import { Controller } from "@hotwired/stimulus"

// Controls live search on the tasks index page.
// Submits the form on keydown/typing with a small debounce.
export default class extends Controller {
  static targets = ["input", "form"]

  connect() {
    this.timeout = null

    // Khi trang reload sau khi search, tự focus lại vào ô search
    if (this.hasInputTarget) {
      // Đợi một tick để đảm bảo layout xong rồi mới focus
      setTimeout(() => {
        this.inputTarget.focus()

        // Đưa con trỏ về cuối chuỗi để người dùng gõ tiếp
        const value = this.inputTarget.value
        this.inputTarget.setSelectionRange?.(value.length, value.length)
      }, 0)
    }
  }

  keydown() {
    // Debounce to avoid submitting on every single keystroke too fast
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      if (this.hasFormTarget) {
        this.formTarget.requestSubmit()
      } else {
        // Fallback: submit closest form element
        this.element.closest("form")?.requestSubmit()
      }
    }, 300)
  }
}

