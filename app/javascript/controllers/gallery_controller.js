import { Controller } from "@hotwired/stimulus"

// Opens a gallery card's details (with trailer, likes and reviews) in a modal.
export default class extends Controller {
  open(event) {
    const card = event.currentTarget
    const modalEl = document.getElementById("movie-modal")
    const body = document.getElementById("movie-modal-body")
    body.replaceChildren(card.querySelector("template").content.cloneNode(true))
    const modal = window.bootstrap.Modal.getOrCreateInstance(modalEl)
    modalEl.addEventListener("hidden.bs.modal", () => body.replaceChildren(), { once: true })
    modal.show()
  }
}
