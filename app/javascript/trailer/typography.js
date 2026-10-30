import { Container, Text, CanvasTextMetrics, TextStyle, Graphics, Sprite, BlurFilter } from "pixi.js"
import { RGBSplitFilter, GlitchFilter } from "pixi-filters"
import { WHITE, lightSweepTexture } from "trailer/shapes"

const MAX_LINE_WIDTH_SHARE = 0.86
const LINE_HEIGHT_FACTOR = 1.08
const MINIMUM_FONT_SIZE = 10
const FONT_SHRINK_STEP = 0.92
const TEXT_RESOLUTION = 2
const FALLBACK_FONTS = ["Oswald", "sans-serif"]
const EXIT_FADE_SECONDS = 0.3

export function buildText(spec, textCard, timeline, random) {
  const [width, height] = spec.size
  const { lines, textStyle } = layoutLines(textCard, width, height)
  const root = new Container()
  root.position.set(width / 2, height * textCard.y)
  root.alpha = 0

  const inner = new Container()
  root.addChild(inner)
  const letters = placeLetters(lines, textStyle, inner)

  const startTime = textCard.start
  const endTime = textCard.start + textCard.duration
  const animate = TEXT_ANIMATIONS[textCard.style] || TEXT_ANIMATIONS.fade_up
  timeline.set(root, { alpha: 1 }, startTime)
  animate({ root, inner, letters, timeline, startTime, endTime, random, textCard, width, height, textStyle })

  const exitWrapper = new Container()
  exitWrapper.addChild(root)
  if (!textCard.title) {
    timeline.fromTo(exitWrapper, { alpha: 1 },
      { alpha: 0, duration: EXIT_FADE_SECONDS, ease: "power1.in", immediateRender: false }, endTime - EXIT_FADE_SECONDS)
  }
  return exitWrapper
}

function placeLetters(lines, textStyle, inner) {
  const letters = []
  const lineHeight = textStyle.fontSize * LINE_HEIGHT_FACTOR
  lines.forEach((line, lineIndex) => {
    const lineWidth = measureWidth(line, textStyle)
    const lineY = (lineIndex - (lines.length - 1) / 2) * lineHeight
    ;[...line].forEach((character, characterIndex) => {
      if (character === " ") return
      const letter = new Text({ text: character, style: textStyle, resolution: TEXT_RESOLUTION })
      letter.anchor.set(0, 0.5)
      letter.x = -lineWidth / 2 + measureWidth(line.slice(0, characterIndex), textStyle)
      letter.y = lineY
      letter.home = { x: letter.x, y: letter.y }
      inner.addChild(letter)
      letters.push(letter)
    })
  })
  return letters
}

function layoutLines(textCard, width, height) {
  let fontSize = textCard.size * height
  let textStyle = createTextStyle(textCard, fontSize)
  let lines = [textCard.text]
  const maxLineWidth = width * MAX_LINE_WIDTH_SHARE
  const fits = (candidateLines, candidateStyle) =>
    candidateLines.every((line) => measureWidth(line, candidateStyle) <= maxLineWidth)

  if (!fits(lines, textStyle) && textCard.text.includes(" ")) lines = splitIntoTwoLines(textCard.text)
  while (!fits(lines, textStyle) && fontSize > MINIMUM_FONT_SIZE) {
    fontSize *= FONT_SHRINK_STEP
    textStyle = createTextStyle(textCard, fontSize)
  }
  return { lines, textStyle }
}

function createTextStyle(textCard, fontSize) {
  return new TextStyle({
    fontFamily: [textCard.font, ...FALLBACK_FONTS],
    fontWeight: String(textCard.weight),
    fontSize,
    fill: textCard.color,
    letterSpacing: textCard.tracking * fontSize,
    dropShadow: { color: "#000000", alpha: 0.55, blur: fontSize * 0.25, distance: 0, angle: 0 },
    padding: fontSize * 0.4
  })
}

function splitIntoTwoLines(text) {
  const words = text.split(" ")
  let bestLines = [text]
  let smallestDifference = Infinity
  for (let splitIndex = 1; splitIndex < words.length; splitIndex++) {
    const firstLine = words.slice(0, splitIndex).join(" ")
    const secondLine = words.slice(splitIndex).join(" ")
    const difference = Math.abs(firstLine.length - secondLine.length)
    if (difference < smallestDifference) {
      smallestDifference = difference
      bestLines = [firstLine, secondLine]
    }
  }
  return bestLines
}

function measureWidth(text, textStyle) {
  return text ? CanvasTextMetrics.measureText(text, textStyle).width : 0
}

function fadeInRoot(timeline, root, startTime, duration, ease) {
  const target = ease ? { alpha: 1, duration, ease, immediateRender: false } : { alpha: 1, duration, immediateRender: false }
  timeline.fromTo(root, { alpha: 0 }, target, startTime)
}

function scaleTween(timeline, target, from, to, duration, ease, startTime) {
  timeline.fromTo(target, { x: from, y: from }, { x: to, y: to, duration, ease }, startTime)
}

const TEXT_ANIMATIONS = {
  fade_up({ root, inner, timeline, startTime }) {
    timeline.fromTo(inner, { y: 18 }, { y: 0, duration: 0.9, ease: "power2.out" }, startTime)
    fadeInRoot(timeline, root, startTime, 0.8, "power1.out")
  },

  letter_spacing({ root, letters, timeline, startTime, endTime }) {
    letters.forEach((letter) => {
      timeline.fromTo(letter, { x: letter.home.x * 1.45 }, { x: letter.home.x, duration: endTime - startTime, ease: "power1.out" }, startTime)
    })
    fadeInRoot(timeline, root, startTime, 0.7)
  },

  per_letter({ letters, timeline, startTime, endTime, random }) {
    const revealOrder = random.shuffle(letters)
    const revealWindow = Math.min(1.4, (endTime - startTime) * 0.5)
    revealOrder.forEach((letter, orderIndex) => {
      timeline.fromTo(letter, { alpha: 0 }, { alpha: 1, duration: 0.25 }, startTime + (orderIndex / revealOrder.length) * revealWindow)
    })
  },

  blur_in({ root, inner, timeline, startTime }) {
    const blur = new BlurFilter({ strength: 14, quality: 3 })
    inner.filters = [blur]
    timeline.fromTo(blur, { strength: 14 }, { strength: 0, duration: 1.1, ease: "power2.out" }, startTime)
    scaleTween(timeline, inner.scale, 1.12, 1, 1.4, "power2.out", startTime)
    fadeInRoot(timeline, root, startTime, 0.9)
    timeline.set(inner, { filters: null }, startTime + 1.15)
  },

  typewriter({ letters, timeline, startTime, endTime }) {
    const letterDelay = Math.min(0.07, ((endTime - startTime) * 0.6) / letters.length)
    letters.forEach((letter, letterIndex) => {
      timeline.fromTo(letter, { alpha: 0 }, { alpha: 1, duration: 0.02 }, startTime + letterIndex * letterDelay)
    })
  },

  glitch({ inner, letters, timeline, startTime, endTime, random }) {
    const colorSplit = new RGBSplitFilter({ red: { x: -6, y: 0 }, green: { x: 0, y: 0 }, blue: { x: 6, y: 0 } })
    const glitch = new GlitchFilter({ slices: 8, offset: 18, seed: random() })
    inner.filters = [colorSplit, glitch]
    letters.forEach((letter) => {
      const jitter = random.range(-14, 14)
      const delay = random.range(0, 0.45)
      timeline.fromTo(letter, { alpha: 0, x: letter.home.x + jitter }, { alpha: 1, x: letter.home.x, duration: 0.05 }, startTime + delay)
    })
    for (let burstIndex = 0; burstIndex < 5; burstIndex++) {
      timeline.set(glitch, { seed: random(), offset: random.range(4, 24) }, startTime + burstIndex * 0.08)
    }
    timeline.set(inner, { filters: [colorSplit] }, startTime + 0.5)
    timeline.to(colorSplit.red, { x: 0, duration: 0.4 }, startTime + 0.5)
    timeline.to(colorSplit.blue, { x: 0, duration: 0.4 }, startTime + 0.5)
    const lateBurstTime = endTime - 0.6
    if (lateBurstTime > startTime + 1) {
      timeline.set(inner, { filters: [glitch] }, lateBurstTime)
      timeline.set(glitch, { seed: random() }, lateBurstTime + 0.06)
      timeline.set(inner, { filters: null }, lateBurstTime + 0.14)
    }
  },

  slam({ root, inner, timeline, startTime }) {
    scaleTween(timeline, inner.scale, 2.8, 1, 0.22, "power4.in", startTime)
    fadeInRoot(timeline, root, startTime, 0.12)
    const shakeOffsets = [8, -7, 5, -4, 2, 0]
    shakeOffsets.forEach((offset, shakeIndex) => {
      timeline.set(inner, { x: offset, y: -offset / 2 }, startTime + 0.22 + shakeIndex * 0.035)
    })
    timeline.to(inner.scale, { x: 1.06, y: 1.06, duration: 3, ease: "none" }, startTime + 0.3)
  },

  split({ letters, timeline, startTime }) {
    letters.forEach((letter, letterIndex) => {
      const direction = letterIndex % 2 ? 1 : -1
      timeline.fromTo(letter, { y: letter.home.y + direction * 40, alpha: 0 },
        { y: letter.home.y, alpha: 1, duration: 0.6, ease: "expo.out" }, startTime + letterIndex * 0.015)
    })
  },

  wipe({ root, inner, timeline, startTime, width, height }) {
    const mask = new Graphics().rect(0, -height / 2, width, height).fill(WHITE)
    mask.x = -width / 2
    mask.scale.x = 0
    root.addChild(mask)
    inner.mask = mask
    timeline.to(mask.scale, { x: 1, duration: 0.8, ease: "power2.inOut" }, startTime)
  },

  scan(animation) {
    TEXT_ANIMATIONS.wipe(animation)
    TEXT_ANIMATIONS.glitch({ ...animation, endTime: animation.startTime + 0.6 })
  },

  zoom_through({ root, inner, timeline, startTime, endTime, textCard }) {
    scaleTween(timeline, inner.scale, 0.6, 1, 0.5, "back.out(1.6)", startTime)
    fadeInRoot(timeline, root, startTime, 0.3)
    if (!textCard.title) timeline.to(inner.scale, { x: 3.2, y: 3.2, duration: 0.35, ease: "power3.in" }, endTime - 0.35)
  },

  zoom_slow({ root, inner, timeline, startTime, endTime }) {
    scaleTween(timeline, inner.scale, 1, 1.14, endTime - startTime, "none", startTime)
    fadeInRoot(timeline, root, startTime, 1.2)
  },

  shine({ root, inner, letters, timeline, startTime, width, textStyle }) {
    fadeInRoot(timeline, root, startTime, 0.9)
    const sweep = new Sprite(lightSweepTexture())
    sweep.anchor.set(0.5)
    sweep.height = textStyle.fontSize * 2.4
    sweep.width = textStyle.fontSize * 1.6
    sweep.blendMode = "add"
    const letterMask = new Container()
    letters.forEach((letter) => {
      const maskLetter = new Text({ text: letter.text, style: letter.style, resolution: TEXT_RESOLUTION })
      maskLetter.anchor.set(0, 0.5)
      maskLetter.position.copyFrom(letter.position)
      letterMask.addChild(maskLetter)
    })
    inner.addChild(letterMask, sweep)
    sweep.mask = letterMask
    timeline.fromTo(sweep, { x: -width * 0.55 }, { x: width * 0.55, duration: 1.3, ease: "power1.inOut" }, startTime + 0.5)
  },

  flicker({ root, timeline, startTime, endTime, random }) {
    let flickerTime = startTime
    for (let flashIndex = 0; flashIndex < 7; flashIndex++) {
      timeline.set(root, { alpha: random() < 0.5 ? 0.15 : 1 }, flickerTime)
      flickerTime += random.range(0.04, 0.12)
    }
    timeline.set(root, { alpha: 1 }, flickerTime)
    const lateFlickerTime = endTime - random.range(0.6, 1.1)
    if (lateFlickerTime > flickerTime + 0.3) {
      timeline.set(root, { alpha: 0.2 }, lateFlickerTime)
      timeline.set(root, { alpha: 1 }, lateFlickerTime + 0.07)
    }
  },

  bounce({ letters, timeline, startTime }) {
    letters.forEach((letter, letterIndex) => {
      timeline.fromTo(letter, { y: letter.home.y - 70, alpha: 0 },
        { y: letter.home.y, alpha: 1, duration: 0.55, ease: "bounce.out" }, startTime + letterIndex * 0.045)
    })
  },

  pop_letters({ letters, timeline, startTime }) {
    letters.forEach((letter, letterIndex) => {
      letter.pivot.set(letter.width / 2, 0)
      letter.x = letter.home.x + letter.width / 2
      timeline.fromTo(letter.scale, { x: 0, y: 0 }, { x: 1, y: 1, duration: 0.5, ease: "elastic.out(1, 0.5)" }, startTime + letterIndex * 0.05)
    })
  }
}
