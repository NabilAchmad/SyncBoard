import { Controller } from "@hotwired/stimulus"

const VALID_THEMES = ["light", "dark", "system"]
const COOKIE_NAME = "syncboard_theme"
const STORAGE_KEY = "syncboard_theme"

export default class extends Controller {
  static targets = ["option"]

  connect() {
    this.mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
    this.onMediaChange = () => {
      if (this.currentPreference() === "system") {
        this.apply(this.currentPreference())
      }
    }
    this.mediaQuery.addEventListener("change", this.onMediaChange)

    this.onTurboLoad = () => this.apply(this.currentPreference())
    document.addEventListener("turbo:load", this.onTurboLoad)

    this.apply(this.currentPreference())
  }

  disconnect() {
    this.mediaQuery?.removeEventListener("change", this.onMediaChange)
    document.removeEventListener("turbo:load", this.onTurboLoad)
  }

  select(event) {
    const mode = event.currentTarget.dataset.themeMode
    if (!VALID_THEMES.includes(mode)) return

    this.persist(mode)
    this.apply(mode)
  }

  toggleQuick() {
    const isCurrentlyDark = document.documentElement.classList.contains("dark")
    const nextMode = isCurrentlyDark ? "light" : "dark"
    this.persist(nextMode)
    this.apply(nextMode)
  }

  currentPreference() {
    try {
      const stored = window.localStorage?.getItem(STORAGE_KEY)
      if (VALID_THEMES.includes(stored)) return stored
    } catch (_e) {}

    const match = document.cookie.match(/(?:^|;\s*)syncboard_theme=([^;]+)/)
    if (match && VALID_THEMES.includes(match[1])) return match[1]

    const htmlPref = document.documentElement.dataset.themePreference
    return VALID_THEMES.includes(htmlPref) ? htmlPref : "light"
  }

  persist(mode) {
    try {
      window.localStorage?.setItem(STORAGE_KEY, mode)
    } catch (_e) {}

    document.cookie = `${COOKIE_NAME}=${mode}; path=/; max-age=31536000; SameSite=Lax`
    document.documentElement.dataset.themePreference = mode
  }

  apply(mode) {
    const prefersDark = Boolean(this.mediaQuery?.matches)
    const isDark = mode === "dark" || (mode === "system" && prefersDark)

    document.documentElement.classList.toggle("dark", isDark)
    document.documentElement.style.colorScheme = isDark ? "dark" : "light"

    this.optionTargets.forEach((btn) => {
      const active = btn.dataset.themeMode === mode
      btn.setAttribute("aria-pressed", String(active))
      btn.classList.toggle("bg-card", active)
      btn.classList.toggle("text-primary-text", active)
      btn.classList.toggle("shadow-2xs", active)
      btn.classList.toggle("border", active)
      btn.classList.toggle("border-outline-variant", active)
      btn.classList.toggle("text-on-surface-muted", !active)
      btn.classList.toggle("hover:text-on-surface", !active)
    })
  }
}

