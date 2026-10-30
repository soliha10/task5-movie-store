import { Application } from "pixi.js"
import { seededRandom } from "trailer/random"
import { buildScene } from "trailer/scene"
import { AudioMix } from "trailer/audio_mix"
import { loadShotVideo, rewindVideos, syncVideos } from "trailer/video_sync"

const MAX_RESOLUTION = 2.5
const FILM_FRAMES_PER_SECOND = 24
const GOLDEN_RATIO_FRACTION = 0.618
const HOLD_FRAME_BEFORE_END_SECONDS = 0.52
const FONT_PROBE_SIZE = "40px"

export class TrailerPlayer {
  constructor(spec, host) {
    this.spec = spec
    this.host = host
    this.random = seededRandom(spec.seed || 1)
    this.videos = []
  }

  get isMuted() {
    return this.audioMix?.isMuted ?? false
  }

  async load(onProgress = () => {}) {
    this.audioMix = new AudioMix(this.spec.audio, this.spec.duration)
    const loadTasks = [...this.videoLoadTasks(), ...this.audioMix.loadTasks(), ...this.fontLoadTasks()]
    let finishedTasks = 0
    await Promise.all(loadTasks.map((task) => task.finally(() => onProgress(++finishedTasks / loadTasks.length))))
    await this.createCanvas()
    const { timeline, filmFilter } = buildScene({ stage: this.app.stage, spec: this.spec, random: this.random })
    this.timeline = timeline
    this.filmFilter = filmFilter
  }

  videoLoadTasks() {
    return this.spec.shots.filter((shot) => shot.type === "clip").map((shot) => {
      const { video, loaded } = loadShotVideo(shot)
      this.videos.push(video)
      return loaded
    })
  }

  fontLoadTasks() {
    return this.spec.texts.map((textCard) =>
      document.fonts.load(`${textCard.weight} ${FONT_PROBE_SIZE} "${textCard.font}"`).catch(() => null))
  }

  async createCanvas() {
    const [width, height] = this.spec.size
    const pixelWidth = this.host.clientWidth * (window.devicePixelRatio || 1)
    const resolution = Math.min(MAX_RESOLUTION, Math.max(1, pixelWidth / width))
    this.app = new Application()
    await this.app.init({ width, height, background: "#000000", antialias: true, autoStart: false, resolution, preference: "webgl" })
    Object.assign(this.app.canvas.style, { width: "100%", height: "100%" })
    this.host.appendChild(this.app.canvas)
  }

  play(onEnd) {
    this.stop()
    this.startTime = this.audioMix.start()
    rewindVideos(this.spec.shots)
    this.isPlaying = true
    const renderNextFrame = () => {
      if (!this.isPlaying) return
      const elapsed = Math.max(0, this.audioMix.currentTime - this.startTime)
      this.renderAt(elapsed)
      if (elapsed >= this.spec.duration) return this.finish(onEnd)
      this.animationFrame = requestAnimationFrame(renderNextFrame)
    }
    this.animationFrame = requestAnimationFrame(renderNextFrame)
  }

  renderAt(elapsed) {
    syncVideos(this.spec.shots, elapsed, this.spec.duration)
    this.timeline.seek(Math.min(elapsed, this.spec.duration), false)
    this.filmFilter.seed = (Math.floor(elapsed * FILM_FRAMES_PER_SECOND) * GOLDEN_RATIO_FRACTION) % 1
    this.app.render()
  }

  finish(onEnd) {
    this.isPlaying = false
    this.pauseVideos()
    this.timeline.seek(Math.max(0, this.spec.duration - HOLD_FRAME_BEFORE_END_SECONDS), false)
    this.app.render()
    onEnd?.()
  }

  setMuted(isMuted) {
    this.audioMix.setMuted(isMuted)
  }

  pauseVideos() {
    this.videos.forEach((video) => video.pause())
  }

  stop() {
    this.isPlaying = false
    cancelAnimationFrame(this.animationFrame)
    this.audioMix?.stop()
    this.pauseVideos()
  }

  destroy() {
    this.stop()
    this.timeline?.kill()
    this.app?.destroy(true, { children: true, texture: true })
    this.videos.forEach((video) => {
      video.removeAttribute("src")
      video.load()
    })
    this.audioMix?.close()
  }
}
