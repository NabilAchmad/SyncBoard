import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "backdrop"]

  toggle() {
    this.panelTarget.classList.toggle("-translate-x-full")
    this.backdropTarget.classList.toggle("hidden")
  }

  close() {
    this.panelTarget.classList.add("-translate-x-full")
    this.backdropTarget.classList.add("hidden")
  }

  async copyCode(event) {
    const button = event.currentTarget
    const code = button.dataset.code
    if (!code) return

    const originalText = button.textContent
    try {
      await navigator.clipboard.writeText(code)
      button.textContent = "Tersalin ✓"
      window.setTimeout(() => {
        button.textContent = originalText
      }, 1800)
    } catch {
      button.textContent = code
    }
  }
}
