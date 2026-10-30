import { Graphics, Texture } from "pixi.js"

export const BLACK = 0x000000
export const WHITE = 0xffffff

export function fullScreenRect(color, width, height) {
  return new Graphics().rect(0, 0, width, height).fill(color)
}

const textureCache = new Map()

export function gradientTexture(name, { width, height, createGradient, stops }) {
  if (textureCache.has(name)) return textureCache.get(name)

  const canvas = document.createElement("canvas")
  canvas.width = width
  canvas.height = height
  const context = canvas.getContext("2d")
  const gradient = createGradient(context, width, height)
  stops.forEach(([offset, color]) => gradient.addColorStop(offset, color))
  context.fillStyle = gradient
  context.fillRect(0, 0, width, height)
  const texture = Texture.from(canvas)
  textureCache.set(name, texture)
  return texture
}

export function lightLeakTexture() {
  return gradientTexture("light-leak", {
    width: 256,
    height: 256,
    createGradient: (context, width) => context.createRadialGradient(width / 2, width / 2, 0, width / 2, width / 2, width / 2),
    stops: [[0, "rgba(255,190,120,0.95)"], [0.4, "rgba(255,120,60,0.5)"], [1, "rgba(255,80,40,0)"]]
  })
}

export function lightSweepTexture() {
  return gradientTexture("light-sweep", {
    width: 128,
    height: 32,
    createGradient: (context, width) => context.createLinearGradient(0, 0, width, 0),
    stops: [[0, "rgba(255,255,255,0)"], [0.5, "rgba(255,255,255,0.9)"], [1, "rgba(255,255,255,0)"]]
  })
}
