import { Controller } from "@hotwired/stimulus"

const DEBOUNCE_MS = 300
const RESULTS_FRAME_ID = "results"
const RANDOM_SEED_HIGH_BITS_MASK = 0x1fffff
const NUMERIC_SEED = /^\d+$/

export default class extends Controller {
  static targets = ["seed", "likes", "likesOutput"]

  submitLater() {
    clearTimeout(this.submitTimer)
    this.submitTimer = setTimeout(() => this.submit(), DEBOUNCE_MS)
  }

  likesMoved() {
    this.likesOutputTarget.textContent = Number(this.likesTarget.value).toFixed(1)
    this.submitLater()
  }

  randomSeed() {
    this.seedTarget.value = randomSeedValue()
    this.submit()
  }

  submit() {
    clearTimeout(this.submitTimer)
    const seedIsValid = NUMERIC_SEED.test(this.seedTarget.value.trim())
    this.seedTarget.classList.toggle("is-invalid", !seedIsValid)
    if (seedIsValid) this.element.requestSubmit()
  }

  scrollToTop() {
    window.scrollTo({ top: 0, behavior: "instant" })
  }

  resultsWillRender(event) {
    if (event.target.id === RESULTS_FRAME_ID) this.scrollToTop()
  }
}

function randomSeedValue() {
  const randomParts = new Uint32Array(2)
  crypto.getRandomValues(randomParts)
  return ((BigInt(randomParts[0] & RANDOM_SEED_HIGH_BITS_MASK) << 32n) | BigInt(randomParts[1])).toString()
}
