const MULBERRY_INCREMENT = 0x6d2b79f5
const UINT32_RANGE = 4294967296

export function seededRandom(seed) {
  let state = seed >>> 0
  const nextRandom = () => {
    state = (state + MULBERRY_INCREMENT) >>> 0
    let mixed = state
    mixed = Math.imul(mixed ^ (mixed >>> 15), mixed | 1)
    mixed ^= mixed + Math.imul(mixed ^ (mixed >>> 7), mixed | 61)
    return ((mixed ^ (mixed >>> 14)) >>> 0) / UINT32_RANGE
  }
  nextRandom.range = (minimum, maximum) => minimum + nextRandom() * (maximum - minimum)
  nextRandom.shuffle = (items) => {
    const shuffled = [...items]
    for (let index = shuffled.length - 1; index > 0; index--) {
      const swapIndex = Math.floor(nextRandom() * (index + 1))
      ;[shuffled[index], shuffled[swapIndex]] = [shuffled[swapIndex], shuffled[index]]
    }
    return shuffled
  }
  return nextRandom
}
