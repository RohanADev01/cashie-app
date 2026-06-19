#!/usr/bin/env swift
// Generates AppIcon.png at 1024×1024, a cute 2D leaf mascot, sprouting,
// on a soft cream background. Matches the brand green palette.
//
//   swift scripts/make_icon.swift

import AppKit
import CoreGraphics

let size: CGFloat = 1024
let outURL = URL(fileURLWithPath: "Cashie/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: Int(size),
    height: Int(size),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("ctx") }

func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> CGColor {
    NSColor(srgbRed: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: a).cgColor
}

// ---------- Background: soft cream → mint pastel ----------
let bgGradient = CGGradient(
    colorsSpace: cs,
    colors: [
        rgb(0xEA, 0xF7, 0xF1),   // top-left mint pastel
        rgb(0xD5, 0xF2, 0xE8),   // bottom-right slightly stronger
    ] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(
    bgGradient,
    start: .zero,
    end: CGPoint(x: size, y: size),
    options: []
)

// ---------- Soft halo behind the leaf ----------
let halo = CGGradient(
    colorsSpace: cs,
    colors: [
        rgb(0x04, 0xBA, 0x74, 0.32),
        rgb(0x04, 0xBA, 0x74, 0.0),
    ] as CFArray,
    locations: [0, 1]
)!
ctx.drawRadialGradient(
    halo,
    startCenter: CGPoint(x: size * 0.50, y: size * 0.55),
    startRadius: 0,
    endCenter: CGPoint(x: size * 0.50, y: size * 0.55),
    endRadius: size * 0.42,
    options: []
)

// ---------- Stem ----------
let stemColor = rgb(0x04, 0xBA, 0x74)
let stemDeep = rgb(0x02, 0x8A, 0x55)

ctx.saveGState()
let stemTop = CGPoint(x: size * 0.50, y: size * 0.46)
let stemBottom = CGPoint(x: size * 0.50, y: size * 0.86)
let stem = CGMutablePath()
stem.move(to: stemBottom)
// Slight S-curve for organic feel
stem.addCurve(
    to: stemTop,
    control1: CGPoint(x: size * 0.48, y: size * 0.72),
    control2: CGPoint(x: size * 0.52, y: size * 0.58)
)
ctx.addPath(stem)
ctx.setStrokeColor(stemDeep)
ctx.setLineWidth(size * 0.045)
ctx.setLineCap(.round)
ctx.strokePath()

// Highlight on the stem (lighter green stripe)
ctx.addPath(stem)
ctx.setStrokeColor(rgb(0x1F, 0xCC, 0x83, 0.85))
ctx.setLineWidth(size * 0.020)
ctx.setLineCap(.round)
ctx.strokePath()
ctx.restoreGState()

// ---------- Leaves: two leaves growing off the stem ----------

func drawLeaf(
    tip: CGPoint,
    base: CGPoint,
    sweep: CGFloat,        // 1 = curl right, -1 = curl left
    fillStart: CGColor,
    fillEnd: CGColor
) {
    let dx = tip.x - base.x
    let dy = tip.y - base.y
    // Perpendicular offset for the leaf belly
    let perp = CGPoint(x: -dy * 0.45 * sweep, y: dx * 0.45 * sweep)
    let outerCtrl1 = CGPoint(x: base.x + dx * 0.3 + perp.x, y: base.y + dy * 0.3 + perp.y)
    let outerCtrl2 = CGPoint(x: base.x + dx * 0.7 + perp.x, y: base.y + dy * 0.7 + perp.y)
    let innerCtrl1 = CGPoint(x: base.x + dx * 0.7 - perp.x * 0.2, y: base.y + dy * 0.7 - perp.y * 0.2)
    let innerCtrl2 = CGPoint(x: base.x + dx * 0.3 - perp.x * 0.2, y: base.y + dy * 0.3 - perp.y * 0.2)

    let path = CGMutablePath()
    path.move(to: base)
    path.addCurve(to: tip, control1: outerCtrl1, control2: outerCtrl2)
    path.addCurve(to: base, control1: innerCtrl1, control2: innerCtrl2)
    path.closeSubpath()

    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()

    let g = CGGradient(
        colorsSpace: cs,
        colors: [fillStart, fillEnd] as CFArray,
        locations: [0, 1]
    )!
    let leafBox = path.boundingBoxOfPath
    ctx.drawLinearGradient(g,
        start: CGPoint(x: leafBox.minX, y: leafBox.maxY),
        end: CGPoint(x: leafBox.maxX, y: leafBox.minY),
        options: []
    )
    ctx.restoreGState()

    // Leaf outline
    ctx.saveGState()
    ctx.addPath(path)
    ctx.setStrokeColor(stemDeep)
    ctx.setLineWidth(size * 0.012)
    ctx.setLineJoin(.round)
    ctx.strokePath()
    ctx.restoreGState()

    // Center vein
    ctx.saveGState()
    ctx.move(to: base)
    let veinCtrl = CGPoint(x: base.x + dx * 0.5 + perp.x * 0.15, y: base.y + dy * 0.5 + perp.y * 0.15)
    ctx.addQuadCurve(to: tip, control: veinCtrl)
    ctx.setStrokeColor(rgb(0x02, 0x8A, 0x55, 0.55))
    ctx.setLineWidth(size * 0.008)
    ctx.setLineCap(.round)
    ctx.strokePath()
    ctx.restoreGState()
}

// Right leaf, bigger, top
drawLeaf(
    tip: CGPoint(x: size * 0.82, y: size * 0.28),
    base: CGPoint(x: size * 0.50, y: size * 0.52),
    sweep: 1,
    fillStart: rgb(0x1F, 0xCC, 0x83),
    fillEnd: rgb(0x04, 0x83, 0x4F)
)

// Left leaf, smaller, lower
drawLeaf(
    tip: CGPoint(x: size * 0.20, y: size * 0.42),
    base: CGPoint(x: size * 0.50, y: size * 0.62),
    sweep: -1,
    fillStart: rgb(0x1F, 0xCC, 0x83),
    fillEnd: rgb(0x04, 0x83, 0x4F)
)

// ---------- Cute face on the right (bigger) leaf ----------
// Coords are in CG (origin bottom-left). To draw within the right leaf, place
// near the geometric center of that leaf.
let faceCenter = CGPoint(x: size * 0.61, y: size * 0.42)
let eyeOffset = size * 0.05
let eyeRadius = size * 0.022

func filledCircle(at p: CGPoint, r: CGFloat, color: CGColor) {
    ctx.setFillColor(color)
    ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
}

// Eyes (white with dark pupil)
let leftEye = CGPoint(x: faceCenter.x - eyeOffset, y: faceCenter.y + size * 0.012)
let rightEye = CGPoint(x: faceCenter.x + eyeOffset, y: faceCenter.y + size * 0.012)
filledCircle(at: leftEye, r: eyeRadius, color: rgb(0xFF, 0xFF, 0xFF))
filledCircle(at: rightEye, r: eyeRadius, color: rgb(0xFF, 0xFF, 0xFF))
filledCircle(at: leftEye, r: eyeRadius * 0.55, color: rgb(0x1A, 0x2A, 0x22))
filledCircle(at: rightEye, r: eyeRadius * 0.55, color: rgb(0x1A, 0x2A, 0x22))
// Eye sparkle
filledCircle(at: CGPoint(x: leftEye.x + eyeRadius * 0.18, y: leftEye.y + eyeRadius * 0.25),
             r: eyeRadius * 0.18, color: rgb(0xFF, 0xFF, 0xFF))
filledCircle(at: CGPoint(x: rightEye.x + eyeRadius * 0.18, y: rightEye.y + eyeRadius * 0.25),
             r: eyeRadius * 0.18, color: rgb(0xFF, 0xFF, 0xFF))

// Smile: small upward arc
ctx.saveGState()
let smileCenter = CGPoint(x: faceCenter.x, y: faceCenter.y - size * 0.025)
let smileRadius = size * 0.030
let smile = CGMutablePath()
smile.addArc(
    center: smileCenter,
    radius: smileRadius,
    startAngle: .pi + 0.4,
    endAngle: 2 * .pi - 0.4,
    clockwise: false
)
ctx.addPath(smile)
ctx.setStrokeColor(rgb(0x1A, 0x2A, 0x22))
ctx.setLineWidth(size * 0.010)
ctx.setLineCap(.round)
ctx.strokePath()
ctx.restoreGState()

// Cheek blushes
filledCircle(at: CGPoint(x: leftEye.x - size * 0.020, y: leftEye.y - size * 0.025),
             r: size * 0.014, color: rgb(0xFF, 0xA8, 0x80, 0.55))
filledCircle(at: CGPoint(x: rightEye.x + size * 0.020, y: rightEye.y - size * 0.025),
             r: size * 0.014, color: rgb(0xFF, 0xA8, 0x80, 0.55))

// ---------- Tiny "growth" sparkles ----------
let sparkles: [(CGFloat, CGFloat, CGFloat)] = [
    (0.18, 0.18, 0.018),
    (0.85, 0.62, 0.014),
    (0.30, 0.78, 0.012),
    (0.78, 0.85, 0.010),
]
for (x, y, r) in sparkles {
    let p = CGPoint(x: size * x, y: size * y)
    filledCircle(at: p, r: size * r, color: rgb(0x04, 0xBA, 0x74, 0.55))
}

// ---------- Save PNG ----------
guard let image = ctx.makeImage() else { fatalError("image") }
let bitmap = NSBitmapImageRep(cgImage: image)
guard let data = bitmap.representation(using: .png, properties: [:]) else { fatalError("png") }
try data.write(to: outURL)
print("Wrote \(outURL.path)")
