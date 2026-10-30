import { Controller } from "@hotwired/stimulus"
import { renderTemplate } from "helpers/template"

export default class extends Controller {
  static targets = ["stage", "status", "controls", "controlsTemplate", "muteIcon"]
  static values = { spec: Object }

  disconnect() {
    this.player?.destroy()
    this.player = null
  }

  async play() {
    if (this.isBusy) return
    this.isBusy = true
    try {
      if (!this.player) await this.loadPlayer()
      this.showStatus("")
      this.element.classList.add("playing")
      this.player.play(() => this.element.classList.remove("playing"))
    } catch (error) {
      console.error(error)
      this.showStatus("Trailer could not be played")
    } finally {
      this.isBusy = false
    }
  }

  async loadPlayer() {
    const { TrailerPlayer } = await import("trailer/player")
    this.player = new TrailerPlayer(structuredClone(this.specValue), this.stageTarget)
    this.showStatus("Loading…")
    await this.player.load((progress) => this.showStatus(`Loading… ${Math.round(progress * 100)}%`))
    this.stageTarget.querySelector(".poster")?.remove()
    renderTemplate(this.controlsTemplateTarget, this.controlsTarget)
  }

  toggleMute() {
    if (!this.player) return
    this.player.setMuted(!this.player.isMuted)
    this.muteIconTarget.className = `bi bi-volume-${this.player.isMuted ? "mute" : "up"}-fill`
  }

  showStatus(text) {
    this.statusTarget.textContent = text
  }
}
