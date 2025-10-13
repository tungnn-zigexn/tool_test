import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["titleInput", "titleCounter", "descInput", "descCounter", "submit"]

  connect() {
    this.updateTitleCount()
    this.updateDescCount()
  }

  updateTitleCount() {
    if (!this.hasTitleInputTarget || !this.hasTitleCounterTarget) return
    const value = this.titleInputTarget.value || ""
    this.titleCounterTarget.textContent = `${value.length}/255`
    this.toggleSubmit()
  }

  updateDescCount() {
    if (!this.hasDescInputTarget || !this.hasDescCounterTarget) return
    const value = this.descInputTarget.value || ""
    this.descCounterTarget.textContent = `${value.length}/1000`
  }

  toggleSubmit() {
    if (!this.hasSubmitTarget || !this.hasTitleInputTarget) return
    const disabled = (this.titleInputTarget.value || "").trim().length === 0
    this.submitTarget.disabled = disabled
  }
}

