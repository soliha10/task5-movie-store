import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row"]

  toggle(event) {
    const row = event.currentTarget
    const open = row.getAttribute("aria-expanded") === "true"
    this.rowTargets.forEach((r) => { if (r !== row) this.collapse(r) })
    open ? this.collapse(row) : this.expand(row)
  }

  expand(row) {
    const details = row.nextElementSibling
    const slot = details.querySelector(".details-slot")
    slot.replaceChildren(details.querySelector("template").content.cloneNode(true))
    details.classList.remove("d-none")
    row.setAttribute("aria-expanded", "true")
    row.classList.add("expanded")
  }

  collapse(row) {
    if (row.getAttribute("aria-expanded") !== "true") return
    const details = row.nextElementSibling
    details.querySelector(".details-slot").replaceChildren()
    details.classList.add("d-none")
    row.setAttribute("aria-expanded", "false")
    row.classList.remove("expanded")
  }
}
