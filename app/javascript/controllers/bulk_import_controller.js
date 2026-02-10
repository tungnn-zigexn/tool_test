import { Controller } from "@hotwired/stimulus"

// Bulk Import modal: load Redmine issues list with date filter, show table with đã/chưa import, import selected.
export default class extends Controller {
  static targets = [
    "listTab",
    "tableTab",
    "listPanel",
    "urlInput",
    "redmineProjectIdInput",
    "redmineProjectFallbackWrap",
    "redmineProjectFallbackInput",
    "startDate",
    "endDate",
    "datePreset",
    "loadButton",
    "tableContainer",
    "tableBody",
    "filterSelect",
    "importForm",
    "selectedCount",
    "progress",
    "submitButton",
    "cancelButton",
    "loadingIndicator"
  ]

  static values = {
    listUrl: String,
    importUrl: String
  }

  connect() {
    this.issues = []
    this.setDefaultDateRange()
  }

  onRedmineProjectChange() {
    this.toggleRedmineProjectFallback()
    const v = this.redmineProjectIdInputTarget?.value?.trim() || ""
    if (v && v !== "__custom__") {
      this.loadList()
    }
  }

  toggleRedmineProjectFallback() {
    const isCustom = this.redmineProjectIdInputTarget?.value === "__custom__"
    if (this.hasRedmineProjectFallbackWrapTarget) {
      this.redmineProjectFallbackWrapTarget.classList.toggle("d-none", !isCustom)
    }
  }

  getRedmineProjectIdValue() {
    const sel = this.redmineProjectIdInputTarget
    if (!sel) return ""
    const v = sel.value?.trim() || ""
    if (v === "__custom__") {
      return this.hasRedmineProjectFallbackInputTarget ? this.redmineProjectFallbackInputTarget.value?.trim() || "" : ""
    }
    return v
  }

  setDefaultDateRange() {
    const range = this.getPresetRange("last_30_days")
    if (this.hasStartDateTarget) this.startDateTarget.value = this.formatDate(range.start)
    if (this.hasEndDateTarget) this.endDateTarget.value = this.formatDate(range.end)
    if (this.hasDatePresetTarget) this.datePresetTarget.value = "last_30_days"
  }

  formatDate(d) {
    const y = d.getFullYear()
    const m = String(d.getMonth() + 1).padStart(2, "0")
    const day = String(d.getDate()).padStart(2, "0")
    return `${y}-${m}-${day}`
  }

  getPresetRange(preset) {
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const addDays = (date, n) => {
      const r = new Date(date)
      r.setDate(r.getDate() + n)
      return r
    }
    const ranges = {
      today: { start: today, end: today },
      yesterday: { start: addDays(today, -1), end: addDays(today, -1) },
      last_7_days: { start: addDays(today, -6), end: today },
      last_30_days: { start: addDays(today, -29), end: today },
      last_90_days: { start: addDays(today, -89), end: today },
      this_month: {
        start: new Date(today.getFullYear(), today.getMonth(), 1),
        end: today
      },
      last_month: {
        start: new Date(today.getFullYear(), today.getMonth() - 1, 1),
        end: new Date(today.getFullYear(), today.getMonth(), 0)
      },
      this_year: { start: new Date(today.getFullYear(), 0, 1), end: today }
    }
    return ranges[preset] || ranges.last_30_days
  }

  selectPreset(event) {
    const preset = event.currentTarget.dataset.preset
    const range = this.getPresetRange(preset)
    if (this.hasStartDateTarget) this.startDateTarget.value = this.formatDate(range.start)
    if (this.hasEndDateTarget) this.endDateTarget.value = this.formatDate(range.end)
    if (this.hasDatePresetTarget) this.datePresetTarget.value = preset

    // Auto-reload if project is selected
    if (this.getRedmineProjectIdValue()) {
      this.loadList()
    }
  }

  async loadList(event) {
    if (event) event.preventDefault()
    const url = this.urlInputTarget?.value?.trim() || ""
    const redmineProjectId = this.getRedmineProjectIdValue()
    const start = this.startDateTarget?.value || ""
    const end = this.endDateTarget?.value || ""
    const preset = this.datePresetTarget?.value || ""

    if (!redmineProjectId) {
      alert("Vui lòng chọn Redmine Project hoặc nhập ID/identifier.")
      return
    }

    const params = new URLSearchParams()
    if (url) params.set("issues_url", url)
    params.set("redmine_project_id", redmineProjectId)
    if (preset) params.set("date_preset", preset)
    if (start) params.set("start_date", start)
    if (end) params.set("end_date", end)

    const listUrl = `${this.listUrlValue}?${params.toString()}`

    // Hide table and show loader
    if (this.hasTableContainerTarget) this.tableContainerTarget.classList.add("d-none")
    if (this.hasLoadingIndicatorTarget) this.loadingIndicatorTarget.classList.remove("d-none")

    try {
      const resp = await fetch(listUrl, {
        headers: { Accept: "application/json", "X-Requested-With": "XMLHttpRequest" }
      })
      const data = await resp.json().catch(() => ({}))
      this.issues = data.issues || []
      if (data.errors && data.errors.length > 0) {
        alert(data.errors.join("\n"))
      }
      this.renderTable()
      this.showTableTab()
    } catch (e) {
      alert("Không thể tải danh sách: " + (e.message || "Lỗi mạng"))
    } finally {
      if (this.hasLoadingIndicatorTarget) this.loadingIndicatorTarget.classList.add("d-none")
    }
  }

  showTableTab() {
    // Only show table if we have issues or just finished loading
    if (this.hasTableContainerTarget) this.tableContainerTarget.classList.remove("d-none")
  }

  showListTab(event) {
    if (event) event.preventDefault()
    if (this.hasTableTabTarget) this.tableTabTarget.classList.remove("active")
    if (this.hasListTabTarget) this.listTabTarget.classList.add("active")
    if (this.hasListPanelTarget) this.listPanelTarget.classList.remove("d-none")
    if (this.hasTableContainerTarget) this.tableContainerTarget.classList.add("d-none")
  }

  renderTable() {
    if (!this.hasTableBodyTarget) return
    const filter = this.filterSelectTarget?.value || "all"
    let rows = this.issues
    if (filter === "not_imported") rows = rows.filter((i) => !i.already_imported)
    if (filter === "imported") rows = rows.filter((i) => i.already_imported)

    const formatDate = (str) => {
      if (!str) return "-"
      try {
        const d = new Date(str)
        return isNaN(d) ? str : d.toLocaleDateString("vi-VN")
      } catch {
        return str
      }
    }

    this.tableBodyTarget.innerHTML = rows
      .map(
        (issue) => `
      <tr class="${issue.already_imported ? "table-secondary" : ""}" data-issue-id="${issue.id}">
        <td>
          ${issue.already_imported ? "" : `<input type="checkbox" class="form-check-input bulk-import-checkbox" name="issue_ids[]" value="${issue.id}" data-action="change->bulk-import#updateSelectedCount">`}
        </td>
        <td>#${issue.id}</td>
        <td>${escapeHtml(issue.subject)}</td>
        <td>${formatDate(issue.created_on)}</td>
        <td>${escapeHtml(issue.assigned_to_name)}</td>
        <td>
          ${issue.already_imported ? '<span class="badge bg-success">Đã import</span>' : '<span class="badge bg-warning text-dark">Chưa import</span>'}
        </td>
      </tr>
    `
      )
      .join("")

    this.updateSelectedCount()
  }

  filterTable() {
    this.renderTable()
  }

  updateSelectedCount() {
    if (!this.hasSelectedCountTarget) return
    const count = this.element.querySelectorAll(".bulk-import-checkbox:checked").length
    this.selectedCountTarget.textContent = count
  }

  toggleAll(event) {
    const checked = event.target.checked
    this.element.querySelectorAll(".bulk-import-checkbox").forEach((cb) => (cb.checked = checked))
    this.updateSelectedCount()
  }

  submitImport(event) {
    event.preventDefault()
    const form = this.hasImportFormTarget ? this.importFormTarget : this.element.querySelector("form[action*='import_selected']")
    if (!form) return
    const checked = this.element.querySelectorAll(".bulk-import-checkbox:checked")
    if (checked.length === 0) {
      alert("Vui lòng chọn ít nhất một task chưa import.")
      return
    }
    form.querySelectorAll('input[name="issue_ids[]"]').forEach((el) => el.remove())
    checked.forEach((cb) => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "issue_ids[]"
      input.value = cb.value
      form.appendChild(input)
    })
    if (this.hasProgressTarget) this.progressTarget.classList.remove("d-none")
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Đang import...'
    }
    if (this.hasCancelButtonTarget) this.cancelButtonTarget.disabled = true
    form.requestSubmit()
  }
}

function escapeHtml(text) {
  const div = document.createElement("div")
  div.textContent = text
  return div.innerHTML
}
