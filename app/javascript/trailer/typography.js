import { Container, Text, CanvasTextMetrics, TextStyle, Graphics, Sprite, Texture, BlurFilter } from "pixi.js"
import { RGBSplitFilter, GlitchFilter } from "pixi-filters"

const MAX_WIDTH = 0.86

export function buildText(spec, card, timeline, rng) {
  const [W, H] = spec.size
  const { lines, style } = layout(card, W, H)
  const root = new Container()
  root.position.set(W / 2, H * card.y)
  root.alpha = 0

  const inner = new Container()
  root.addChild(inner)
  const letters = []
  const lineHeight = style.fontSize * 1.08
  lines.forEach((line, row) => {
    const width = measure(line, style)
    const y = (row - (lines.length - 1) / 2) * lineHeight
    ;[...line].forEach((ch, i) => {
      if (ch === " ") return
      const letter = new Text({ text: ch, style, resolution: 2 })
      letter.anchor.set(0, 0.5)
      letter.x = -width / 2 + measure(line.slice(0, i), style)
      letter.y = y
      letter.home = { x: letter.x, y: letter.y }
      inner.addChild(letter)
      letters.push(letter)
    })
  })

  const start = card.start
  const end = card.start + card.duration
  const animate = STYLES[card.style] || STYLES.fade_up
  timeline.set(root, { alpha: 1 }, start)
  animate({ root, inner, letters, timeline, start, end, rng, card, W, H, style })

  const outer = new Container()
  outer.addChild(root)
  if (!card.title) {
    timeline.fromTo(outer, { alpha: 1 }, { alpha: 0, duration: 0.3, ease: "power1.in", immediateRender: false }, end - 0.3)
  }
  return outer
}

function layout(card, W, H) {
  let fontSize = card.size * H
  const make = (size) => new TextStyle({
    fontFamily: [card.font, "Oswald", "sans-serif"],
    fontWeight: String(card.weight),
    fontSize: size,
    fill: card.color,
    letterSpacing: card.tracking * size,
    dropShadow: { color: "#000000", alpha: 0.55, blur: size * 0.25, distance: 0, angle: 0 },
    padding: size * 0.4
  })
  let style = make(fontSize)
  let lines = [card.text]
  const fits = (ls, s) => ls.every((l) => measure(l, s) <= W * MAX_WIDTH)

  if (!fits(lines, style) && card.text.includes(" ")) lines = splitInTwo(card.text)
  while (!fits(lines, style) && fontSize > 10) {
    fontSize *= 0.92
    style = make(fontSize)
  }
  return { lines, style }
}

function splitInTwo(text) {
  const words = text.split(" ")
  let best = [text]
  let bestDiff = Infinity
  for (let i = 1; i < words.length; i++) {
    const a = words.slice(0, i).join(" ")
    const b = words.slice(i).join(" ")
    const diff = Math.abs(a.length - b.length)
    if (diff < bestDiff) { bestDiff = diff; best = [a, b] }
  }
  return best
}

function measure(text, style) {
  return text ? CanvasTextMetrics.measureText(text, style).width : 0
}

const STYLES = {
  fade_up({ root, inner, timeline, start }) {
    timeline.fromTo(inner, { y: 18 }, { y: 0, duration: 0.9, ease: "power2.out" }, start)
    timeline.fromTo(root, { alpha: 0 }, { alpha: 1, duration: 0.8, ease: "power1.out", immediateRender: false }, start)
  },

  letter_spacing({ root, letters, timeline, start, end }) {
    const span = end - start
    letters.forEach((l) => {
      timeline.fromTo(l, { x: l.home.x * 1.45 }, { x: l.home.x, duration: span, ease: "power1.out" }, start)
    })
    timeline.fromTo(root, { alpha: 0 }, { alpha: 1, duration: 0.7, immediateRender: false }, start)
  },

  per_letter({ letters, timeline, start, end, rng }) {
    const order = rng.shuffle(letters)
    const window = Math.min(1.4, (end - start) * 0.5)
    order.forEach((l, i) => {
      timeline.fromTo(l, { alpha: 0 }, { alpha: 1, duration: 0.25 }, start + (i / order.length) * window)
    })
  },

  blur_in({ root, inner, timeline, start }) {
    const blur = new BlurFilter({ strength: 14, quality: 3 })
    inner.filters = [blur]
    timeline.fromTo(blur, { strength: 14 }, { strength: 0, duration: 1.1, ease: "power2.out" }, start)
    timeline.fromTo(inner.scale, { x: 1.12, y: 1.12 }, { x: 1, y: 1, duration: 1.4, ease: "power2.out" }, start)
    timeline.fromTo(root, { alpha: 0 }, { alpha: 1, duration: 0.9, immediateRender: false }, start)
    timeline.set(inner, { filters: null }, start + 1.15)
  },

  typewriter({ letters, timeline, start, end }) {
    const step = Math.min(0.07, ((end - start) * 0.6) / letters.length)
    letters.forEach((l, i) => timeline.fromTo(l, { alpha: 0 }, { alpha: 1, duration: 0.02 }, start + i * step))
  },

  glitch({ inner, letters, timeline, start, end, rng }) {
    const split = new RGBSplitFilter({ red: { x: -6, y: 0 }, green: { x: 0, y: 0 }, blue: { x: 6, y: 0 } })
    const glitch = new GlitchFilter({ slices: 8, offset: 18, seed: rng() })
    inner.filters = [split, glitch]
    letters.forEach((l) => {
      const jitter = rng.range(-14, 14)
      timeline.fromTo(l, { alpha: 0, x: l.home.x + jitter }, { alpha: 1, x: l.home.x, duration: 0.05 }, start + rng.range(0, 0.45))
    })
    for (let i = 0; i < 5; i++) {
      timeline.set(glitch, { seed: rng(), offset: rng.range(4, 24) }, start + i * 0.08)
    }
    timeline.set(inner, { filters: [split] }, start + 0.5)
    timeline.to(split.red, { x: 0, duration: 0.4 }, start + 0.5)
    timeline.to(split.blue, { x: 0, duration: 0.4 }, start + 0.5)
    const t = end - 0.6
    if (t > start + 1) {
      timeline.set(inner, { filters: [glitch] }, t)
      timeline.set(glitch, { seed: rng() }, t + 0.06)
      timeline.set(inner, { filters: null }, t + 0.14)
    }
  },

  slam({ root, inner, timeline, start }) {
    timeline.fromTo(inner.scale, { x: 2.8, y: 2.8 }, { x: 1, y: 1, duration: 0.22, ease: "power4.in" }, start)
    timeline.fromTo(root, { alpha: 0 }, { alpha: 1, duration: 0.12, immediateRender: false }, start)
    const shake = [8, -7, 5, -4, 2, 0]
    shake.forEach((dx, i) => timeline.set(inner, { x: dx, y: -dx / 2 }, start + 0.22 + i * 0.035))
    timeline.to(inner.scale, { x: 1.06, y: 1.06, duration: 3, ease: "none" }, start + 0.3)
  },

  split({ letters, timeline, start }) {
    letters.forEach((l, i) => {
      const dir = i % 2 ? 1 : -1
      timeline.fromTo(l, { y: l.home.y + dir * 40, alpha: 0 }, { y: l.home.y, alpha: 1, duration: 0.6, ease: "expo.out" }, start + i * 0.015)
    })
  },

  wipe({ root, inner, timeline, start, W, H }) {
    const mask = new Graphics().rect(0, -H / 2, W, H).fill(0xffffff)
    mask.x = -W / 2
    mask.scale.x = 0
    root.addChild(mask)
    inner.mask = mask
    timeline.to(mask.scale, { x: 1, duration: 0.8, ease: "power2.inOut" }, start)
  },

  scan(args) {
    STYLES.wipe(args)
    STYLES.glitch({ ...args, end: args.start + 0.6 })
  },

  zoom_through({ root, inner, timeline, start, end, card }) {
    timeline.fromTo(inner.scale, { x: 0.6, y: 0.6 }, { x: 1, y: 1, duration: 0.5, ease: "back.out(1.6)" }, start)
    timeline.fromTo(root, { alpha: 0 }, { alpha: 1, duration: 0.3, immediateRender: false }, start)
    if (!card.title) timeline.to(inner.scale, { x: 3.2, y: 3.2, duration: 0.35, ease: "power3.in" }, end - 0.35)
  },

  zoom_slow({ root, inner, timeline, start, end }) {
    timeline.fromTo(inner.scale, { x: 1, y: 1 }, { x: 1.14, y: 1.14, duration: end - start, ease: "none" }, start)
    timeline.fromTo(root, { alpha: 0 }, { alpha: 1, duration: 1.2, immediateRender: false }, start)
  },

  shine({ root, inner, letters, timeline, start, W, H, style }) {
    timeline.fromTo(root, { alpha: 0 }, { alpha: 1, duration: 0.9, immediateRender: false }, start)
    const sweep = new Sprite(sweepTexture())
    sweep.anchor.set(0.5)
    sweep.height = style.fontSize * 2.4
    sweep.width = style.fontSize * 1.6
    sweep.blendMode = "add"
    const mask = new Container()
    letters.forEach((l) => {
      const copy = new Text({ text: l.text, style: l.style, resolution: 2 })
      copy.anchor.set(0, 0.5)
      copy.position.copyFrom(l.position)
      mask.addChild(copy)
    })
    inner.addChild(mask, sweep)
    sweep.mask = mask
    timeline.fromTo(sweep, { x: -W * 0.55 }, { x: W * 0.55, duration: 1.3, ease: "power1.inOut" }, start + 0.5)
  },

  flicker({ root, timeline, start, end, rng }) {
    let t = start
    for (let i = 0; i < 7; i++) {
      timeline.set(root, { alpha: rng() < 0.5 ? 0.15 : 1 }, t)
      t += rng.range(0.04, 0.12)
    }
    timeline.set(root, { alpha: 1 }, t)
    const late = end - rng.range(0.6, 1.1)
    if (late > t + 0.3) {
      timeline.set(root, { alpha: 0.2 }, late)
      timeline.set(root, { alpha: 1 }, late + 0.07)
    }
  },

  bounce({ letters, timeline, start }) {
    letters.forEach((l, i) => {
      timeline.fromTo(l, { y: l.home.y - 70, alpha: 0 }, { y: l.home.y, alpha: 1, duration: 0.55, ease: "bounce.out" }, start + i * 0.045)
    })
  },

  pop_letters({ letters, timeline, start }) {
    letters.forEach((l, i) => {
      l.pivot.set(l.width / 2, 0)
      l.x = l.home.x + l.width / 2
      timeline.fromTo(l.scale, { x: 0, y: 0 }, { x: 1, y: 1, duration: 0.5, ease: "elastic.out(1, 0.5)" }, start + i * 0.05)
    })
  }
}

let cachedSweep
function sweepTexture() {
  if (cachedSweep) return cachedSweep
  const canvas = document.createElement("canvas")
  canvas.width = 128
  canvas.height = 32
  const ctx = canvas.getContext("2d")
  const g = ctx.createLinearGradient(0, 0, 128, 0)
  g.addColorStop(0, "rgba(255,255,255,0)")
  g.addColorStop(0.5, "rgba(255,255,255,0.9)")
  g.addColorStop(1, "rgba(255,255,255,0)")
  ctx.fillStyle = g
  ctx.fillRect(0, 0, 128, 32)
  cachedSweep = Texture.from(canvas)
  return cachedSweep
}
