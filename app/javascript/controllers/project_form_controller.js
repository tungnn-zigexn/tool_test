import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["nameInput", "nameCounter", "descInput", "descCounter", "submit"]

  connect() {
    this.updateNameCount()
    this.updateDescCount()
  }

  updateNameCount() {
    if (!this.hasNameInputTarget || !this.hasNameCounterTarget) return
    const value = this.nameInputTarget.value || ""
    this.nameCounterTarget.textContent = `${value.length}/255`
    this.toggleSubmit()
  }

  updateDescCount() {
    if (!this.hasDescInputTarget || !this.hasDescCounterTarget) return
    const value = this.descInputTarget.value || ""
    this.descCounterTarget.textContent = `${value.length}/1000`
  }

  toggleSubmit() {
    if (!this.hasSubmitTarget || !this.hasNameInputTarget) return
    const disabled = (this.nameInputTarget.value || "").trim().length === 0
    this.submitTarget.disabled = disabled
  }
}




