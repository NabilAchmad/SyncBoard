import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["quickAddPanel", "toggleButton", "scopeTab", "completionAction"]
  static values = { currentUserId: Number }

  connect() {
    this.activeScope = "all"
    this.observer = new MutationObserver(() => {
      this.applyScope()
      this.evaluateCompletion()
    })
    const boardContainer = document.getElementById("project_kanban_board")?.parentElement || this.element
    this.observer.observe(boardContainer, { childList: true, subtree: true })
    this.evaluateCompletion()
  }

  disconnect() {
    this.observer?.disconnect()
  }

  toggleQuickAdd() {
    if (!this.hasQuickAddPanelTarget) return
    const isHidden = this.quickAddPanelTarget.classList.toggle("hidden")
    if (this.hasToggleButtonTarget) {
      this.toggleButtonTarget.setAttribute("aria-expanded", isHidden ? "false" : "true")
    }
    if (!isHidden) {
      const titleInput = this.quickAddPanelTarget.querySelector('input[type="text"]')
      titleInput?.focus()
    }
  }

  filterScope(event) {
    this.activeScope = event.currentTarget.dataset.scope || "all"

    this.scopeTabTargets.forEach((tab) => {
      const selected = tab.dataset.scope === this.activeScope
      tab.setAttribute("aria-pressed", selected ? "true" : "false")
      tab.className = `inline-flex min-h-11 sm:min-h-7 items-center rounded-[7px] px-2.5 py-1 text-xs font-semibold transition cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary ${
        selected
          ? "border border-outline-variant bg-card text-on-surface shadow-2xs"
          : "border border-transparent text-on-surface-muted hover:text-on-surface"
      }`
    })

    this.applyScope()
  }

  applyScope() {
    const cards = this.element.querySelectorAll('[data-kanban-target="card"]')
    cards.forEach((card) => {
      const hideCard = this.activeScope === "mine" && Number(card.dataset.assigneeId) !== this.currentUserIdValue
      card.classList.toggle("hidden", hideCard)
    })
  }

  evaluateCompletion() {
    if (!this.hasCompletionActionTarget) return
    const isCompleted = this.completionActionTarget.dataset.projectCompleted === "true"
    if (isCompleted) {
      this.completionActionTarget.classList.remove("hidden")
      return
    }

    const cards = Array.from(this.element.querySelectorAll('[data-kanban-target="card"]'))
    const allInDone = cards.length > 0 && cards.every((card) => card.dataset.column === "done")
    this.completionActionTarget.classList.toggle("hidden", !allInDone)
  }
}
