const READY_STATE_CURRENT_DATA = 2
const LOAD_TIMEOUT_MS = 12000
const START_TOLERANCE_SECONDS = 0.05
const PLAY_TAIL_SECONDS = 0.1
const DRIFT_TOLERANCE_SECONDS = 0.3
const END_MARGIN_SECONDS = 0.05

export function loadShotVideo(shot) {
  const video = document.createElement("video")
  Object.assign(video, { muted: true, playsInline: true, preload: "auto", crossOrigin: "anonymous", loop: false })
  video.setAttribute("playsinline", "")
  shot.video = video
  const loaded = new Promise((resolve) => {
    const seekToInPoint = () => {
      video.currentTime = shot.in
      video.addEventListener("seeked", resolve, { once: true })
    }
    video.addEventListener("loadeddata", seekToInPoint, { once: true })
    video.addEventListener("error", resolve, { once: true })
    video.src = shot.url
    setTimeout(resolve, LOAD_TIMEOUT_MS)
  })
  return { video, loaded }
}

export function isVideoReady(video) {
  return Boolean(video) && video.readyState >= READY_STATE_CURRENT_DATA
}

export function shotVisibleUntil(shots, shotIndex, totalDuration) {
  const nextShot = shots[shotIndex + 1]
  return nextShot ? nextShot.start + (nextShot.transition?.duration || 0) : totalDuration + 1
}

export function rewindVideos(shots) {
  shots.forEach((shot) => {
    if (!shot.video) return
    shot.video.pause()
    shot.video.currentTime = shot.in
    shot.video.playbackRate = shot.speed
  })
}

export function syncVideos(shots, time, totalDuration) {
  shots.forEach((shot, shotIndex) => {
    const video = shot.video
    if (!isVideoReady(video) || !Number.isFinite(video.duration)) return

    const playUntil = shotVisibleUntil(shots, shotIndex, totalDuration) + PLAY_TAIL_SECONDS
    const isActive = time >= shot.start - START_TOLERANCE_SECONDS && time < playUntil
    if (!isActive) {
      if (!video.paused) video.pause()
      return
    }
    keepVideoOnTime(video, shot.in + Math.max(0, time - shot.start) * shot.speed)
  })
}

function keepVideoOnTime(video, expectedTime) {
  const lastPlayableTime = video.duration - END_MARGIN_SECONDS
  if (Math.abs(video.currentTime - expectedTime) > DRIFT_TOLERANCE_SECONDS && !video.seeking) {
    video.currentTime = Math.min(expectedTime, lastPlayableTime)
  }
  if (video.paused && video.currentTime < lastPlayableTime) video.play().catch(() => {})
}
