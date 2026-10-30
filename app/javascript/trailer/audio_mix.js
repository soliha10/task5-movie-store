const START_DELAY_SECONDS = 0.12
const MUSIC_FADE_OUT_SECONDS = 1.2
const SILENT_GAIN = 0.0001

export class AudioMix {
  constructor(audioSpec, totalDuration) {
    this.audioSpec = audioSpec || {}
    this.totalDuration = totalDuration
    this.context = new (window.AudioContext || window.webkitAudioContext)()
    this.masterGain = this.context.createGain()
    this.masterGain.connect(this.context.destination)
    this.buffers = {}
    this.activeSources = []
    this.isMuted = false
  }

  loadTasks() {
    const { music, sfx = [] } = this.audioSpec
    const urls = [music?.url, ...sfx.map((soundEffect) => soundEffect.url)].filter(Boolean)
    return urls.map((url) => this.loadSound(url))
  }

  async loadSound(url) {
    if (this.buffers[url]) return
    try {
      const data = await (await fetch(url)).arrayBuffer()
      this.buffers[url] = await this.context.decodeAudioData(data)
    } catch (error) {
      console.warn("trailer audio failed", url, error)
    }
  }

  start() {
    const startTime = this.context.currentTime + START_DELAY_SECONDS
    this.context.resume()
    const { music, sfx = [] } = this.audioSpec
    if (music) this.scheduleSound(startTime, music.url, 0, music.gain, music.offset, this.totalDuration - MUSIC_FADE_OUT_SECONDS)
    sfx.forEach((soundEffect) => this.scheduleSound(startTime, soundEffect.url, soundEffect.t, soundEffect.gain))
    return startTime
  }

  scheduleSound(startTime, url, delay, gain, offset = 0, fadeOutAt = null) {
    const buffer = this.buffers[url]
    if (!buffer) return

    const bufferSource = this.context.createBufferSource()
    bufferSource.buffer = buffer
    const gainNode = this.context.createGain()
    gainNode.gain.setValueAtTime(gain, startTime + delay)
    if (fadeOutAt) {
      gainNode.gain.setValueAtTime(gain, startTime + fadeOutAt)
      gainNode.gain.linearRampToValueAtTime(SILENT_GAIN, startTime + this.totalDuration)
    }
    bufferSource.connect(gainNode).connect(this.masterGain)
    bufferSource.start(startTime + delay, offset)
    this.activeSources.push(bufferSource)
  }

  get currentTime() {
    return this.context.currentTime
  }

  setMuted(isMuted) {
    this.isMuted = isMuted
    this.masterGain.gain.value = isMuted ? 0 : 1
  }

  stop() {
    this.activeSources.forEach((bufferSource) => {
      try { bufferSource.stop() } catch {}
    })
    this.activeSources = []
  }

  close() {
    this.stop()
    this.context.close()
  }
}
