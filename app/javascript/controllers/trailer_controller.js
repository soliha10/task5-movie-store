import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["stage", "play", "status"]
  static values = { spec: Object, title: String }

  play() {
    this.statusTarget.textContent = "Trailer player coming soon"
  }
}
