import { Container, Sprite, Texture, VideoSource, Graphics, Rectangle } from "pixi.js"
import { AdjustmentFilter, OldFilmFilter, AdvancedBloomFilter, RGBSplitFilter } from "pixi-filters"
import { gsap } from "gsap"
import { BLACK, WHITE, fullScreenRect, lightLeakTexture } from "trailer/shapes"
import { isVideoReady, shotVisibleUntil } from "trailer/video_sync"
import { addTransition } from "trailer/transitions"
import { buildText } from "trailer/typography"

const TINT_STRENGTH = 1.7
const LETTERBOX_SHARE = 0.11
const MOTION_OVERRUN_SECONDS = 0.8
const DIM_DELAY_SECONDS = 0.3
const DIM_FADE_SECONDS = 1.2
const OPENING_FADE_SECONDS = 0.4
const CLOSING_FADE_SECONDS = 0.5

export function buildScene({ stage, spec, random }) {
  const [width, height] = spec.size
  const timeline = gsap.timeline({ paused: true })
  const screen = new Container()
  screen.filterArea = new Rectangle(0, 0, width, height)
  stage.addChild(screen)

  const world = new Container()
  world.filterArea = new Rectangle(0, 0, width, height)
  world.filters = gradeFilters(spec.grade)
  screen.addChild(world)

  const scene = { timeline, world, width, height, random }
  spec.shots.forEach((shot, shotIndex) => addShot(scene, spec, shot, shotIndex))
  addOverlays(scene, screen)
  spec.shots.forEach((shot) => addTransition(scene, shot))
  if (spec.letterbox) screen.addChild(letterboxBars(width, height))
  const textLayer = new Container()
  screen.addChild(textLayer)
  spec.texts.forEach((textCard) => textLayer.addChild(buildText(spec, textCard, timeline, random)))

  const filmFilter = filmLook(spec.grade)
  screen.filters = [filmFilter]
  addOpeningAndClosing(timeline, screen, spec.duration)
  return { timeline, filmFilter }
}

function gradeFilters(grade) {
  const tint = hexToRgb(grade.tint)
  const channelMultiplier = (channel) => 1 + (channel * TINT_STRENGTH - 1) * grade.tint_amount
  const filters = [new AdjustmentFilter({
    saturation: grade.saturation, contrast: grade.contrast, brightness: grade.brightness,
    red: channelMultiplier(tint.red), green: channelMultiplier(tint.green), blue: channelMultiplier(tint.blue)
  })]
  if (grade.bloom > 0) {
    filters.push(new AdvancedBloomFilter({ threshold: 0.55, bloomScale: grade.bloom * 2.2, brightness: 1, blur: 6, quality: 4 }))
  }
  if (grade.rgb_split > 0) {
    filters.push(new RGBSplitFilter({ red: { x: -grade.rgb_split, y: 0 }, green: { x: 0, y: 0 }, blue: { x: grade.rgb_split, y: 0 } }))
  }
  return filters
}

function filmLook(grade) {
  return new OldFilmFilter({
    sepia: 0, noise: grade.grain, noiseSize: 1, scratch: grade.grain > 0.12 ? 0.4 : 0, scratchDensity: 0.25,
    scratchWidth: 1, vignetting: 0.18 + grade.vignette * 0.22, vignettingAlpha: Math.min(1, 0.5 + grade.vignette * 0.6),
    vignettingBlur: 0.35
  })
}

function addShot(scene, spec, shot, shotIndex) {
  const layer = new Container()
  layer.visible = false
  shot.layer = layer
  if (shot.type === "clip" && isVideoReady(shot.video)) {
    addFootage(scene, layer, shot)
  } else {
    layer.addChild(fullScreenRect(BLACK, scene.width, scene.height))
  }
  scene.world.addChild(layer)
  scene.timeline.set(layer, { visible: true }, shot.start)
  scene.timeline.set(layer, { visible: false }, shotVisibleUntil(spec.shots, shotIndex, spec.duration))
}

function addFootage(scene, layer, shot) {
  const { timeline, width, height } = scene
  const source = new VideoSource({ resource: shot.video, autoPlay: false, autoLoad: true, updateFPS: 0 })
  const sprite = new Sprite(new Texture({ source }))
  sprite.anchor.set(0.5)
  const coverScale = Math.max(width / shot.video.videoWidth, height / shot.video.videoHeight)
  const flipDirection = shot.flip ? -1 : 1
  const [zoomStart, zoomEnd] = shot.zoom
  const panPosition = (pan, zoom) => ({ x: width / 2 + pan[0] * (zoom - 1) * width / 2, y: height / 2 + pan[1] * (zoom - 1) * height / 2 })
  const startPosition = panPosition(shot.pan[0], zoomStart)
  const endPosition = panPosition(shot.pan[1], zoomEnd)
  const motionSeconds = shot.duration + MOTION_OVERRUN_SECONDS
  sprite.position.set(startPosition.x, startPosition.y)
  timeline.fromTo(sprite.scale, { x: coverScale * zoomStart * flipDirection, y: coverScale * zoomStart },
    { x: coverScale * zoomEnd * flipDirection, y: coverScale * zoomEnd, duration: motionSeconds, ease: "none" }, shot.start)
  timeline.fromTo(sprite.position, startPosition, { ...endPosition, duration: motionSeconds, ease: "none" }, shot.start)
  layer.addChild(sprite)
  if (shot.dim > 0) addDimming(scene, layer, shot)
}

function addDimming(scene, layer, shot) {
  const dimming = fullScreenRect(BLACK, scene.width, scene.height)
  dimming.alpha = 0
  layer.addChild(dimming)
  scene.timeline.to(dimming, { alpha: shot.dim, duration: DIM_FADE_SECONDS }, shot.start + DIM_DELAY_SECONDS)
}

function addOverlays(scene, screen) {
  const { width, height } = scene
  scene.flashLayer = fullScreenRect(WHITE, width, height)
  scene.flashLayer.alpha = 0
  scene.blackLayer = fullScreenRect(BLACK, width, height)
  scene.blackLayer.alpha = 0
  scene.lightLeak = new Sprite(lightLeakTexture())
  Object.assign(scene.lightLeak, { blendMode: "add", alpha: 0, height: height * 1.6, width: width * 1.1, y: height / 2 })
  scene.lightLeak.anchor.set(0.5)
  screen.addChild(scene.lightLeak, scene.flashLayer, scene.blackLayer)
}

function letterboxBars(width, height) {
  const barHeight = height * LETTERBOX_SHARE
  return new Graphics().rect(0, 0, width, barHeight).rect(0, height - barHeight, width, barHeight).fill(BLACK)
}

function addOpeningAndClosing(timeline, screen, duration) {
  timeline.fromTo(screen, { alpha: 0 }, { alpha: 1, duration: OPENING_FADE_SECONDS }, 0)
  timeline.to(screen, { alpha: 0, duration: CLOSING_FADE_SECONDS, ease: "power1.in" }, duration - CLOSING_FADE_SECONDS)
  timeline.set({}, {}, duration)
}

function hexToRgb(hex) {
  const value = parseInt((hex || "#ffffff").slice(1), 16)
  return { red: ((value >> 16) & 255) / 255, green: ((value >> 8) & 255) / 255, blue: (value & 255) / 255 }
}
