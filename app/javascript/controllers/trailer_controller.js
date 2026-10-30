import { Controller } from "@hotwired/stimulus"

// Shows the poster (freeze frame with the title) and plays the generated trailer on demand.
export default class extends Controller {
  static targets = ["stage", "play", "status"]
  static values = { spec: Object, title: String }

  disconnect() {
    this.player?.destroy()
    this.player = null
  }

  async play() {
    if (this.busy) return
    this.busy = true
    try {
      if (!this.player) {
        const { TrailerPlayer } = await import("trailer/player")
        this.player = new TrailerPlayer(structuredClone(this.specValue), this.stageTarget)
        this.status("Loading…")
        await this.player.load((p) => this.status(`Loading… ${Math.round(p * 100)}%`))
        this.stageTarget.querySelector(".poster")?.remove()
        this.addControls()
      }
      this.status("")
      this.element.classList.add("playing")
      this.player.play(() => this.element.classList.remove("playing"))
    } catch (error) {
      console.error(error)
      this.status("Trailer could not be played")
    } finally {
      this.busy = false
    }
  }

  toggleMute() {
    if (!this.player) return
    this.player.setMuted(!this.player.muted)
    this.muteButton.innerHTML = `<i class="bi bi-volume-${this.player.muted ? "mute" : "up"}-fill"></i>`
  }

  addControls() {
    const bar = document.createElement("div")
    bar.className = "trailer-controls"
    bar.innerHTML = `<button type="button" data-action="trailer#play" title="Replay"><i class="bi bi-arrow-counterclockwise"></i></button>
      <button type="button" data-action="trailer#toggleMute" title="Mute"><i class="bi bi-volume-up-fill"></i></button>`
    this.muteButton = bar.lastElementChild
    this.element.appendChild(bar)
  }

  status(text) {
    this.statusTarget.textContent = text
  }
}
