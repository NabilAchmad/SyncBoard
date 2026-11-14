import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "backdrop", "searchInput", "projectItem", "projectEmpty"]

  toggle() {
    this.panelTarget.classList.toggle("-translate-x-full")
    this.backdropTarget.classList.toggle("hidden")
  }

  close() {
    this.panelTarget.classList.add("-translate-x-full")
    this.backdropTarget.classList.add("hidden")
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
      return
    }

    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
      if (this.hasSearchInputTarget) {
        event.preventDefault()
        this.panelTarget.classList.remove("-translate-x-full")
        this.backdropTarget.classList.toggle("hidden", window.innerWidth >= 1024)
        this.searchInputTarget.focus()
        this.searchInputTarget.select()
      }
    }
  }

  filterProjects() {
    if (!this.hasSearchInputTarget) return

    const query = this.searchInputTarget.value.trim().toLowerCase()
    let visibleCount = 0

    this.projectItemTargets.forEach((item) => {
      const searchText = (item.dataset.searchText || item.textContent || "").toLowerCase()
      const matches = !query || searchText.includes(query)
      item.classList.toggle("hidden", !matches)
      if (matches) visibleCount += 1
    })

    if (this.hasProjectEmptyTarget) {
      this.projectEmptyTarget.classList.toggle("hidden", visibleCount > 0 || !query)
    }
  }

  async copyCode(event) {
    const button = event.currentTarget
    const code = button.dataset.code
    if (!code) return

    const originalText = button.textContent
    try {
      await navigator.clipboard.writeText(code)
      button.textContent = "Tersalin"
      window.setTimeout(() => {
        button.textContent = originalText
      }, 1800)
    } catch {
      button.textContent = code
    }
  }
}
