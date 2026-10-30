import { Controller } from "@hotwired/stimulus"
import { renderTemplate } from "helpers/template"

export default class extends Controller {
  static targets = ["row"]

  toggle(event) {
    const clickedRow = event.currentTarget
    const wasExpanded = isExpanded(clickedRow)
    this.rowTargets.forEach((row) => this.collapse(row))
    if (!wasExpanded) this.expand(clickedRow)
  }

  expand(row) {
    const detailsRow = row.nextElementSibling
    renderTemplate(detailsRow.querySelector("template"), detailsRow.querySelector(".details-slot"))
    this.setExpanded(row, true)
  }

  collapse(row) {
    if (!isExpanded(row)) return
    row.nextElementSibling.querySelector(".details-slot").replaceChildren()
    this.setExpanded(row, false)
  }

  setExpanded(row, expanded) {
    row.setAttribute("aria-expanded", String(expanded))
    row.classList.toggle("expanded", expanded)
    row.nextElementSibling.classList.toggle("d-none", !expanded)
  }
}

function isExpanded(row) {
  return row.getAttribute("aria-expanded") === "true"
}
