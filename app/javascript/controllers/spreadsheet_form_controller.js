import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "basicGrid", "stepsGrid", "formSection"]

  connect() {
    this.stepCount = this.stepsGridTarget.querySelectorAll(".test-step-row").length
  }

  toggleForm(event) {
    if (event) event.preventDefault()
    this.formSectionTarget.classList.toggle("d-none")
    if (!this.formSectionTarget.classList.contains("d-none") && this.stepCount === 0) {
      this.addStep()
    }
  }

  addStep(event) {
    if (event) event.preventDefault()
    this.stepCount++
    const uniqueId = new Date().getTime() + Math.floor(Math.random() * 1000)
    
    const rowHtml = `
      <tr class="test-step-row" data-unique-id="${uniqueId}">
        <td class="text-center fw-bold step-number">${this.stepCount}</td>
        <td>
          <div class="rich-editor-wrapper">
            <div contenteditable="true" 
                 class="form-control border-0 bg-transparent rich-editor" 
                 data-action="input->spreadsheet-form#syncContent"
                 placeholder="Nhập Test Step..."></div>
            <input type="hidden" name="test_case[test_steps_attributes][${uniqueId}][test_step_contents_attributes][0][content_value]" value="">
            <input type="hidden" name="test_case[test_steps_attributes][${uniqueId}][step_number]" value="${this.stepCount}">
            <input type="hidden" name="test_case[test_steps_attributes][${uniqueId}][test_step_contents_attributes][0][content_category]" value="action">
            <input type="hidden" name="test_case[test_steps_attributes][${uniqueId}][test_step_contents_attributes][0][content_type]" value="text">
            <input type="hidden" name="test_case[test_steps_attributes][${uniqueId}][test_step_contents_attributes][0][display_order]" value="0">
          </div>
        </td>
        <td>
          <div class="rich-editor-wrapper">
            <div contenteditable="true" 
                 class="form-control border-0 bg-transparent rich-editor text-success" 
                 data-action="input->spreadsheet-form#syncContent"
                 placeholder="Nhập Expect Result (Optional)..."></div>
            <input type="hidden" name="test_case[test_steps_attributes][${uniqueId}][test_step_contents_attributes][1][content_value]" value="">
            <input type="hidden" name="test_case[test_steps_attributes][${uniqueId}][test_step_contents_attributes][1][content_category]" value="expectation">
            <input type="hidden" name="test_case[test_steps_attributes][${uniqueId}][test_step_contents_attributes][1][content_type]" value="text">
            <input type="hidden" name="test_case[test_steps_attributes][${uniqueId}][test_step_contents_attributes][1][display_order]" value="0">
          </div>
        </td>
        <td class="text-center align-middle">
          <button type="button" class="btn btn-link text-danger p-0" data-action="click->spreadsheet-form#removeStep">
            <i class="bi bi-x-circle-fill"></i>
          </button>
        </td>
      </tr>
    `
    this.stepsGridTarget.insertAdjacentHTML('beforeend', rowHtml)
    
    // Focus the new editor
    const lastRow = this.stepsGridTarget.lastElementChild
    lastRow.querySelector('[contenteditable]').focus()
  }

  syncContent(event) {
    const editor = event.target
    const hiddenInput = editor.nextElementSibling
    hiddenInput.value = editor.innerHTML
  }

  applyStyle(event) {
    event.preventDefault()
    const command = event.currentTarget.dataset.command
    const value = event.currentTarget.dataset.value || null
    
    document.execCommand(command, false, value)
    
    // Trigger sync for all editors in case selection was weird
    this.stepsGridTarget.querySelectorAll('[contenteditable]').forEach(editor => {
      const hiddenInput = editor.nextElementSibling
      hiddenInput.value = editor.innerHTML
    })
  }

  removeStep(event) {
    event.preventDefault()
    const row = event.target.closest(".test-step-row")
    row.remove()
    this.renumberSteps()
  }

  renumberSteps() {
    this.stepCount = 0
    this.stepsGridTarget.querySelectorAll(".test-step-row").forEach((row, index) => {
      this.stepCount = index + 1
      row.querySelector(".step-number").textContent = this.stepCount
      row.querySelector("input[name*='[step_number]']").value = this.stepCount
    })
  }

  resetForm() {
    // Store current function and test_type to "carry over" for convenience
    const functionVal = this.formSectionTarget.querySelector('[name*="[function]"]').value
    const testTypeVal = this.formSectionTarget.querySelector('[name*="[test_type]"]').value

    this.formSectionTarget.classList.add("d-none")
    this.stepsGridTarget.innerHTML = ""
    this.stepCount = 0
    
    // Reset inputs but re-apply carried over values
    this.basicGridTarget.querySelectorAll("input, select").forEach(el => el.value = "")
    this.formSectionTarget.querySelector('[name*="[function]"]').value = functionVal
    this.formSectionTarget.querySelector('[name*="[test_type]"]').value = testTypeVal
    
    // Focus title for next entry if form is toggled again
    this.formSectionTarget.querySelector('[name*="[title]"]').focus()
  }
}
