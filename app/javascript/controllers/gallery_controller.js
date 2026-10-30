import { Controller } from "@hotwired/stimulus"
import { renderTemplate } from "helpers/template"

const MODAL_ID = "movie-modal"
const MODAL_BODY_ID = "movie-modal-body"

export default class extends Controller {
  open(event) {
    const modalElement = document.getElementById(MODAL_ID)
    const modalBody = document.getElementById(MODAL_BODY_ID)
    renderTemplate(event.currentTarget.querySelector("template"), modalBody)
    modalElement.addEventListener("hidden.bs.modal", () => modalBody.replaceChildren(), { once: true })
    window.bootstrap.Modal.getOrCreateInstance(modalElement).show()
  }
}
