import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["column", "list", "card"]

  connect() {
    this.draggedCard = null
  }

  dragStart(event) {
    const card = event.currentTarget
    this.draggedCard = card
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", card.dataset.taskId)
    requestAnimationFrame(() => {
      card.classList.add("opacity-50", "ring-2", "ring-indigo-400")
    })
  }

  dragEnd(event) {
    const card = event.currentTarget
    card.classList.remove("opacity-50", "ring-2", "ring-indigo-400")
    this.clearDropHighlights()
    this.draggedCard = null
  }

  dragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    const columnEl = event.currentTarget
    columnEl.classList.add("ring-2", "ring-indigo-400/70", "bg-indigo-50/40")
  }

  dragLeave(event) {
    const columnEl = event.currentTarget
    if (!columnEl.contains(event.relatedTarget)) {
      columnEl.classList.remove("ring-2", "ring-indigo-400/70", "bg-indigo-50/40")
    }
  }

  async drop(event) {
    event.preventDefault()
    this.clearDropHighlights()

    const columnEl = event.currentTarget
    const targetColumn = columnEl.dataset.column
    const taskId = event.dataTransfer.getData("text/plain")
    const card = this.draggedCard || this.element.querySelector(`[data-task-id="${taskId}"]`)
    if (!card || !targetColumn) return

    const listEl = columnEl.querySelector('[data-kanban-target="list"]') || columnEl
    const moveUrl = card.dataset.moveUrl
    const sourceColumn = card.dataset.column

    listEl.appendChild(card)
    card.dataset.column = targetColumn

    const cardsInList = Array.from(listEl.querySelectorAll('[data-kanban-target="card"]'))
    const targetPosition = cardsInList.indexOf(card) + 1

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    if (!moveUrl) return

    try {
      const response = await fetch(moveUrl, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": csrfToken || ""
        },
        body: JSON.stringify({
          column_status: targetColumn,
          position: targetPosition
        })
      })

      if (!response.ok) {
        if (sourceColumn) card.dataset.column = sourceColumn
        console.error("Gagal memindahkan kartu Kanban:", response.status)
      }
    } catch (error) {
      console.error("Error koneksi saat memindahkan kartu:", error)
    }
  }

  clearDropHighlights() {
    this.columnTargets.forEach((col) => {
      col.classList.remove("ring-2", "ring-indigo-400/70", "bg-indigo-50/40")
    })
  }
}

