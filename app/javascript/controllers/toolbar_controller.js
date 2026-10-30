import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["seed", "likes", "likesOutput"]

  changed(event) {
    if (event.target === this.seedTarget || event.target.name === "reviews" || event.target === this.likesTarget) return
    this.submit()
  }

  debounced() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.submit(), 300)
  }

  likesMoved() {
    this.likesOutputTarget.textContent = Number(this.likesTarget.value).toFixed(1)
    this.debounced()
  }

  randomSeed() {
    const parts = new Uint32Array(2)
    crypto.getRandomValues(parts)
    const seed = (BigInt(parts[0] & 0x1fffff) << 32n) | BigInt(parts[1])
    this.seedTarget.value = seed.toString()
    this.submit()
  }

  submit() {
    clearTimeout(this.timer)
    if (!/^\d+$/.test(this.seedTarget.value.trim())) {
      this.seedTarget.classList.add("is-invalid")
      return
    }
    this.seedTarget.classList.remove("is-invalid")
    this.element.requestSubmit()
  }

  submitted() {
    window.scrollTo({ top: 0, behavior: "instant" })
  }

  rendered(event) {
    if (event.target.id === "results") window.scrollTo({ top: 0, behavior: "instant" })
  }
}
