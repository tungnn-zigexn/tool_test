import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step", "indicator", "prevBtn", "nextBtn"]
  static values = { index: Number }

  initialize() {
    this.jumpToLast = this.jumpToLast.bind(this)
  }

  connect() {
    this.indexValue = 0
    this.showCurrentStep()
    document.addEventListener("test-step:added", this.jumpToLast)
  }

  disconnect() {
    document.removeEventListener("test-step:added", this.jumpToLast)
  }

  next(event) {
    if (event) event.preventDefault()
    if (this.indexValue < this.stepTargets.length - 1) {
      this.indexValue++
      this.showCurrentStep()
    }
  }

  previous(event) {
    if (event) event.preventDefault()
    if (this.indexValue > 0) {
      this.indexValue--
      this.showCurrentStep()
    }
  }

  jumpToLast() {
    // We need a slight delay to let Turbo render the new target
    setTimeout(() => {
      this.indexValue = this.stepTargets.length - 1
      this.showCurrentStep()
    }, 50)
  }

  showCurrentStep() {
    this.stepTargets.forEach((el, i) => {
      el.classList.toggle("d-none", i !== this.indexValue)
    })

    if (this.hasIndicatorTarget) {
      this.indicatorTarget.textContent = `Step ${this.indexValue + 1} / ${this.stepTargets.length}`
    }

    if (this.hasPrevBtnTarget) {
      this.prevBtnTarget.disabled = this.indexValue === 0
    }

    if (this.hasNextBtnTarget) {
      this.nextBtnTarget.disabled = this.indexValue === this.stepTargets.length - 1
    }
  }
}
