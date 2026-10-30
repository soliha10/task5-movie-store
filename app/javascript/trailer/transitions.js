import { ZoomBlurFilter, MotionBlurFilter, GlitchFilter, RGBSplitFilter } from "pixi-filters"

const CUT = { type: "cut", duration: 0 }

export function addTransition(scene, shot) {
  const { type, duration } = shot.transition || CUT
  TRANSITIONS[type]?.({ scene, shot, transitionDuration: duration, cutTime: shot.start })
}

function fadeInLayer(timeline, layer, duration, cutTime, ease) {
  const target = ease ? { alpha: 1, duration, ease } : { alpha: 1, duration }
  timeline.fromTo(layer, { alpha: 0 }, target, cutTime)
}

function filterForDuration(timeline, layer, filter, cutTime, transitionDuration) {
  layer.filters = [filter]
  timeline.set(layer, { filters: null }, cutTime + transitionDuration)
}

function dipThrough(overlay) {
  return ({ scene, transitionDuration, cutTime }) => {
    const halfDuration = transitionDuration / 2
    scene.timeline.to(scene[overlay], { alpha: 1, duration: halfDuration, ease: "power1.in" }, cutTime - halfDuration)
    scene.timeline.to(scene[overlay], { alpha: 0, duration: halfDuration, ease: "power1.out" }, cutTime)
  }
}

const TRANSITIONS = {
  dissolve({ scene, shot, transitionDuration, cutTime }) {
    fadeInLayer(scene.timeline, shot.layer, transitionDuration, cutTime, "none")
  },

  fade_in({ scene, shot, transitionDuration, cutTime }) {
    fadeInLayer(scene.timeline, shot.layer, transitionDuration, cutTime)
  },

  flash({ scene, transitionDuration, cutTime }) {
    scene.timeline.fromTo(scene.flashLayer, { alpha: 0.95 },
      { alpha: 0, duration: transitionDuration + 0.15, ease: "power2.out", immediateRender: false }, cutTime)
  },

  dip_black: dipThrough("blackLayer"),
  dip_white: dipThrough("flashLayer"),

  zoom_blur({ scene, shot, transitionDuration, cutTime }) {
    const zoomBlur = new ZoomBlurFilter({ strength: 0.35, center: { x: scene.width / 2, y: scene.height / 2 }, innerRadius: 20 })
    filterForDuration(scene.timeline, shot.layer, zoomBlur, cutTime, transitionDuration)
    scene.timeline.fromTo(zoomBlur, { strength: 0.35 }, { strength: 0, duration: transitionDuration, ease: "power2.out" }, cutTime)
  },

  whip({ scene, shot, transitionDuration, cutTime }) {
    const motionBlur = new MotionBlurFilter({ velocity: { x: 70, y: 0 }, kernelSize: 15 })
    filterForDuration(scene.timeline, shot.layer, motionBlur, cutTime, transitionDuration)
    scene.timeline.fromTo(shot.layer, { x: scene.width * 0.35 }, { x: 0, duration: transitionDuration, ease: "power3.out" }, cutTime)
    scene.timeline.to(motionBlur.velocity, { x: 0, duration: transitionDuration, ease: "power2.out" }, cutTime)
  },

  glitch({ scene, transitionDuration, cutTime }) {
    const glitch = new GlitchFilter({ slices: 10, offset: 30, seed: scene.random() })
    const colorSplit = new RGBSplitFilter({ red: { x: -8, y: 2 }, green: { x: 0, y: 0 }, blue: { x: 8, y: -2 } })
    const gradeFilters = scene.world.filters
    const glitchStart = cutTime - 0.08
    scene.timeline.set(scene.world, { filters: [...gradeFilters, glitch, colorSplit] }, glitchStart)
    for (let burstIndex = 0; burstIndex < 5; burstIndex++) {
      scene.timeline.set(glitch, { seed: scene.random(), offset: scene.random.range(10, 40) }, glitchStart + burstIndex * 0.06)
    }
    scene.timeline.set(scene.world, { filters: gradeFilters }, cutTime + transitionDuration)
  },

  light_leak({ scene, shot, transitionDuration, cutTime }) {
    const { timeline, lightLeak, width } = scene
    timeline.fromTo(lightLeak, { x: -width * 0.2, alpha: 0 },
      { x: width * 0.6, alpha: 0.85, duration: transitionDuration * 0.6, ease: "power1.in", immediateRender: false }, cutTime - transitionDuration * 0.4)
    timeline.to(lightLeak, { x: width * 1.1, alpha: 0, duration: transitionDuration * 0.6, ease: "power1.out" }, cutTime + transitionDuration * 0.2)
    fadeInLayer(timeline, shot.layer, transitionDuration * 0.5, cutTime)
  },

  flicker({ scene, shot, transitionDuration, cutTime }) {
    for (let flashIndex = 0; flashIndex < 4; flashIndex++) {
      scene.timeline.set(shot.layer, { alpha: flashIndex % 2 ? 1 : 0.2 }, cutTime + flashIndex * (transitionDuration / 4))
    }
    scene.timeline.set(shot.layer, { alpha: 1 }, cutTime + transitionDuration)
  }
}
