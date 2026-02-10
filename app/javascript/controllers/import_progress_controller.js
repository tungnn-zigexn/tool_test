import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="import-progress"
export default class extends Controller {
  static targets = ["form", "progress", "submitButton", "cancelButton"]
  static values = {
    estimatedTime: { type: Number, default: 45 } // Estimated time in seconds
  }

  connect() {
    console.log("Import Progress controller connected")
    this.progressInterval = null
    this.startTime = null
  }

  disconnect() {
    this.clearProgressInterval()
  }

  // Show progress bar and disable form when submit
  showProgress(event) {
    // Show progress bar
    if (this.hasProgressTarget) {
      this.progressTarget.classList.remove("d-none")
    }

    // Disable submit button
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.innerHTML = `
        <span class="spinner-border spinner-border-sm me-2" role="status" aria-hidden="true"></span>
        Đang import...
      `
    }

    // Disable cancel button
    if (this.hasCancelButtonTarget) {
      this.cancelButtonTarget.disabled = true
    }

    // Start linear progress based on estimated time
    this.startLinearProgress()
  }

  startLinearProgress() {
    const progressBar = this.element.querySelector('.progress-bar')
    const timeRemainingElement = this.element.querySelector('.time-remaining')
    if (!progressBar) return

    this.startTime = Date.now()
    let progress = 0
    
    // Update every 300ms for smooth animation
    const updateInterval = 300
    
    // Calculate increment per interval to reach 95% by estimated time
    // We stop at 95% to leave 5% for actual completion
    const targetProgress = 95
    const totalIntervals = (this.estimatedTimeValue * 1000) / updateInterval
    const incrementPerInterval = targetProgress / totalIntervals

    this.clearProgressInterval()
    
    this.progressInterval = setInterval(() => {
      const elapsed = (Date.now() - this.startTime) / 1000 // seconds
      
      // Linear progress based on time
      progress = (elapsed / this.estimatedTimeValue) * targetProgress
      
      // Calculate remaining time
      const remaining = Math.max(0, this.estimatedTimeValue - elapsed)
      
      // Cap at 95%
      if (progress >= targetProgress) {
        progress = targetProgress
        this.updateProgressBar(progressBar, progress, 0, timeRemainingElement)
        this.clearProgressInterval()
        return
      }

      this.updateProgressBar(progressBar, progress, remaining, timeRemainingElement)
    }, updateInterval)
  }

  updateProgressBar(progressBar, progress, timeRemaining = null, timeRemainingElement = null) {
    const roundedProgress = Math.round(progress)
    progressBar.style.width = `${roundedProgress}%`
    progressBar.setAttribute('aria-valuenow', roundedProgress)
    progressBar.textContent = `${roundedProgress}%`

    // Update time remaining if element exists
    if (timeRemainingElement && timeRemaining !== null) {
      const seconds = Math.ceil(timeRemaining)
      timeRemainingElement.textContent = `Còn khoảng ${seconds} giây...`
    }
  }

  clearProgressInterval() {
    if (this.progressInterval) {
      clearInterval(this.progressInterval)
      this.progressInterval = null
    }
  }

  // Call this when import is complete (if using AJAX)
  complete() {
    const progressBar = this.element.querySelector('.progress-bar')
    if (progressBar) {
      this.updateProgressBar(progressBar, 100)
    }
    this.clearProgressInterval()
  }

  // Reset form state (if needed for SPA behavior)
  reset() {
    this.clearProgressInterval()
    
    if (this.hasProgressTarget) {
      this.progressTarget.classList.add("d-none")
    }

    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
    }

    if (this.hasCancelButtonTarget) {
      this.cancelButtonTarget.disabled = false
    }

    // Reset progress bar
    const progressBar = this.element.querySelector('.progress-bar')
    if (progressBar) {
      this.updateProgressBar(progressBar, 0)
    }
  }
}

