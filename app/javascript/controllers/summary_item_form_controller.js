import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["existingGroup", "titleInput", "targetTaskSelect", "existingActionSelect"]
  static values = { mode: { type: String, default: "create" } }

  connect() {
    this.sync()
  }

  switchMode(event) {
    this.modeValue = event.currentTarget.value
    this.sync()
  }

  sync() {
    const isExisting = this.modeValue === "existing"

    if (this.hasExistingGroupTarget) {
      this.existingGroupTarget.classList.toggle("hidden", !isExisting)
    }

    if (this.hasTargetTaskSelectTarget) {
      this.targetTaskSelectTarget.disabled = !isExisting
      this.targetTaskSelectTarget.required = isExisting
    }

    if (this.hasExistingActionSelectTarget) {
      this.existingActionSelectTarget.disabled = !isExisting
    }

    if (this.hasTitleInputTarget) {
      this.titleInputTarget.required = !isExisting
      this.titleInputTarget.placeholder = isExisting
        ? "Catatan update (opsional, kosongkan untuk pakai judul ticket asli)..."
        : "Judul ticket / task baru..."
    }
  }
}
