#!/usr/bin/env swift
// Generates several App Icon options at 1024×1024 in `icon_options/`.
// Each variant is a distinct aesthetic, pick one, copy it to
// Cashie/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png.
//
//   swift scripts/make_icon_options.swift

import AppKit
import CoreGraphics

let size: CGFloat = 1024
let outDir = URL(fileURLWithPath: "icon_options")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let cs = CGColorSpaceCreateDeviceRGB()

func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> CGColor {
    NSColor(srgbRed: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: a).cgColor
}

func makeContext() -> CGContext {
    CGContext(
        data: nil,
        width: Int(size),
        height: Int(size),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
}

func savePNG(_ ctx: CGContext, named name: String) {
    let cgImage = ctx.makeImage()!
    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    let data = bitmap.representation(using: .png, properties: [:])!
    let url = outDir.appendingPathComponent("\(name).png")
    try! data.write(to: url)
    print("Wrote \(url.path)")
}

func filledCircle(_ ctx: CGContext, at p: CGPoint, r: CGFloat, color: CGColor) {
    ctx.setFillColor(color)
    ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
}

// Brand palette
let brand = rgb(0x04, 0xBA, 0x74)
let brandLight = rgb(0x1F, 0xCC, 0x83)
let brandDeep = rgb(0x04, 0x83, 0x4F)
let cream = rgb(0xEA, 0xF7, 0xF1)
let creamWarm = rgb(0xD5, 0xF2, 0xE8)
let ink = rgb(0x11, 0x11, 0x11)

// =========================================================================
// 1. LEAF MASCOT, kawaii sprout with face. GenZ Duolingo vibes.
// =========================================================================
func leafMascot() {
    let ctx = makeContext()

    let bg = CGGradient(colorsSpace: cs, colors: [cream, creamWarm] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: .zero, end: CGPoint(x: size, y: size), options: [])

    let halo = CGGradient(colorsSpace: cs,
                          colors: [rgb(0x04, 0xBA, 0x74, 0.30), rgb(0x04, 0xBA, 0x74, 0.0)] as CFArray,
                          locations: [0, 1])!
    ctx.drawRadialGradient(halo,
        startCenter: CGPoint(x: size * 0.5, y: size * 0.55), startRadius: 0,
        endCenter: CGPoint(x: size * 0.5, y: size * 0.55), endRadius: size * 0.42, options: [])

    // Stem
    let stem = CGMutablePath()
    stem.move(to: CGPoint(x: size * 0.50, y: size * 0.86))
    stem.addCurve(to: CGPoint(x: size * 0.50, y: size * 0.46),
                  control1: CGPoint(x: size * 0.48, y: size * 0.72),
                  control2: CGPoint(x: size * 0.52, y: size * 0.58))
    ctx.addPath(stem)
    ctx.setStrokeColor(brandDeep)
    ctx.setLineWidth(size * 0.045)
    ctx.setLineCap(.round)
    ctx.strokePath()

    func drawLeaf(tip: CGPoint, base: CGPoint, sweep: CGFloat) {
        let dx = tip.x - base.x, dy = tip.y - base.y
        let perp = CGPoint(x: -dy * 0.45 * sweep, y: dx * 0.45 * sweep)
        let path = CGMutablePath()
        path.move(to: base)
        path.addCurve(to: tip,
                      control1: CGPoint(x: base.x + dx * 0.3 + perp.x, y: base.y + dy * 0.3 + perp.y),
                      control2: CGPoint(x: base.x + dx * 0.7 + perp.x, y: base.y + dy * 0.7 + perp.y))
        path.addCurve(to: base,
                      control1: CGPoint(x: base.x + dx * 0.7 - perp.x * 0.2, y: base.y + dy * 0.7 - perp.y * 0.2),
                      control2: CGPoint(x: base.x + dx * 0.3 - perp.x * 0.2, y: base.y + dy * 0.3 - perp.y * 0.2))
        path.closeSubpath()
        ctx.saveGState()
        ctx.addPath(path); ctx.clip()
        let g = CGGradient(colorsSpace: cs, colors: [brandLight, brandDeep] as CFArray, locations: [0, 1])!
        let bb = path.boundingBoxOfPath
        ctx.drawLinearGradient(g, start: CGPoint(x: bb.minX, y: bb.maxY), end: CGPoint(x: bb.maxX, y: bb.minY), options: [])
        ctx.restoreGState()
        ctx.addPath(path)
        ctx.setStrokeColor(brandDeep); ctx.setLineWidth(size * 0.012); ctx.setLineJoin(.round); ctx.strokePath()
    }

    drawLeaf(tip: CGPoint(x: size * 0.82, y: size * 0.28), base: CGPoint(x: size * 0.50, y: size * 0.52), sweep: 1)
    drawLeaf(tip: CGPoint(x: size * 0.20, y: size * 0.42), base: CGPoint(x: size * 0.50, y: size * 0.62), sweep: -1)

    // Face on right leaf
    let face = CGPoint(x: size * 0.61, y: size * 0.42)
    let eyeOff = size * 0.05, eyeR = size * 0.024
    let leftEye = CGPoint(x: face.x - eyeOff, y: face.y + size * 0.012)
    let rightEye = CGPoint(x: face.x + eyeOff, y: face.y + size * 0.012)
    filledCircle(ctx, at: leftEye, r: eyeR, color: rgb(0xFF, 0xFF, 0xFF))
    filledCircle(ctx, at: rightEye, r: eyeR, color: rgb(0xFF, 0xFF, 0xFF))
    filledCircle(ctx, at: leftEye, r: eyeR * 0.55, color: rgb(0x1A, 0x2A, 0x22))
    filledCircle(ctx, at: rightEye, r: eyeR * 0.55, color: rgb(0x1A, 0x2A, 0x22))
    filledCircle(ctx, at: CGPoint(x: leftEye.x + eyeR * 0.18, y: leftEye.y + eyeR * 0.25),
                 r: eyeR * 0.18, color: rgb(0xFF, 0xFF, 0xFF))
    filledCircle(ctx, at: CGPoint(x: rightEye.x + eyeR * 0.18, y: rightEye.y + eyeR * 0.25),
                 r: eyeR * 0.18, color: rgb(0xFF, 0xFF, 0xFF))

    // Smile
    let smile = CGMutablePath()
    smile.addArc(center: CGPoint(x: face.x, y: face.y - size * 0.025),
                 radius: size * 0.030,
                 startAngle: .pi + 0.4, endAngle: 2 * .pi - 0.4, clockwise: false)
    ctx.addPath(smile)
    ctx.setStrokeColor(rgb(0x1A, 0x2A, 0x22))
    ctx.setLineWidth(size * 0.010); ctx.setLineCap(.round); ctx.strokePath()

    // Blushes
    filledCircle(ctx, at: CGPoint(x: leftEye.x - size * 0.020, y: leftEye.y - size * 0.025),
                 r: size * 0.014, color: rgb(0xFF, 0xA8, 0x80, 0.55))
    filledCircle(ctx, at: CGPoint(x: rightEye.x + size * 0.020, y: rightEye.y - size * 0.025),
                 r: size * 0.014, color: rgb(0xFF, 0xA8, 0x80, 0.55))

    savePNG(ctx, named: "01_leaf_mascot")
}

// =========================================================================
// 2. COIN CHARACTER, golden 3D coin with cute face. Mascot.
// =========================================================================
func coinCharacter() {
    let ctx = makeContext()

    // Cream background
    ctx.setFillColor(rgb(0xFB, 0xF8, 0xF0))
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

    // Soft halo
    let halo = CGGradient(colorsSpace: cs,
                          colors: [rgb(0x04, 0xBA, 0x74, 0.32), rgb(0x04, 0xBA, 0x74, 0.0)] as CFArray,
                          locations: [0, 1])!
    ctx.drawRadialGradient(halo,
        startCenter: CGPoint(x: size * 0.5, y: size * 0.5), startRadius: 0,
        endCenter: CGPoint(x: size * 0.5, y: size * 0.5), endRadius: size * 0.45, options: [])

    // Coin radial fill
    let coinSize = size * 0.62
    let coinRect = CGRect(x: (size - coinSize) / 2, y: (size - coinSize) / 2, width: coinSize, height: coinSize)
    ctx.saveGState()
    ctx.addPath(CGPath(ellipseIn: coinRect, transform: nil)); ctx.clip()
    let coinGrad = CGGradient(colorsSpace: cs,
        colors: [brandLight, brand, brandDeep] as CFArray, locations: [0, 0.55, 1])!
    ctx.drawRadialGradient(coinGrad,
        startCenter: CGPoint(x: coinRect.minX + coinSize * 0.32, y: coinRect.minY + coinSize * 0.72),
        startRadius: coinSize * 0.05,
        endCenter: CGPoint(x: coinRect.midX, y: coinRect.midY),
        endRadius: coinSize * 0.55, options: [.drawsAfterEndLocation])
    ctx.restoreGState()

    // Outer ring
    ctx.addPath(CGPath(ellipseIn: coinRect, transform: nil))
    ctx.setStrokeColor(brandDeep); ctx.setLineWidth(size * 0.020); ctx.strokePath()

    // Inner highlight
    ctx.addPath(CGPath(ellipseIn: coinRect.insetBy(dx: size * 0.030, dy: size * 0.030), transform: nil))
    ctx.setStrokeColor(rgb(0xFF, 0xFF, 0xFF, 0.35)); ctx.setLineWidth(size * 0.010); ctx.strokePath()

    // Eyes
    let face = CGPoint(x: coinRect.midX, y: coinRect.midY)
    let eyeOff = size * 0.06, eyeR = size * 0.030
    let leftEye = CGPoint(x: face.x - eyeOff, y: face.y + size * 0.020)
    let rightEye = CGPoint(x: face.x + eyeOff, y: face.y + size * 0.020)
    filledCircle(ctx, at: leftEye, r: eyeR, color: rgb(0xFF, 0xFF, 0xFF))
    filledCircle(ctx, at: rightEye, r: eyeR, color: rgb(0xFF, 0xFF, 0xFF))
    filledCircle(ctx, at: leftEye, r: eyeR * 0.55, color: rgb(0x1A, 0x2A, 0x22))
    filledCircle(ctx, at: rightEye, r: eyeR * 0.55, color: rgb(0x1A, 0x2A, 0x22))
    filledCircle(ctx, at: CGPoint(x: leftEye.x + eyeR * 0.20, y: leftEye.y + eyeR * 0.25),
                 r: eyeR * 0.22, color: rgb(0xFF, 0xFF, 0xFF))
    filledCircle(ctx, at: CGPoint(x: rightEye.x + eyeR * 0.20, y: rightEye.y + eyeR * 0.25),
                 r: eyeR * 0.22, color: rgb(0xFF, 0xFF, 0xFF))

    // Smile
    let smile = CGMutablePath()
    smile.addArc(center: CGPoint(x: face.x, y: face.y - size * 0.030),
                 radius: size * 0.045,
                 startAngle: .pi + 0.35, endAngle: 2 * .pi - 0.35, clockwise: false)
    ctx.addPath(smile)
    ctx.setStrokeColor(rgb(0x1A, 0x2A, 0x22))
    ctx.setLineWidth(size * 0.012); ctx.setLineCap(.round); ctx.strokePath()

    // Cheek blushes
    filledCircle(ctx, at: CGPoint(x: leftEye.x - size * 0.030, y: leftEye.y - size * 0.040),
                 r: size * 0.022, color: rgb(0xFF, 0xA8, 0x80, 0.55))
    filledCircle(ctx, at: CGPoint(x: rightEye.x + size * 0.030, y: rightEye.y - size * 0.040),
                 r: size * 0.022, color: rgb(0xFF, 0xA8, 0x80, 0.55))

    savePNG(ctx, named: "02_coin_character")
}

// =========================================================================
// 3. STICKER DOLLAR, Y2K bold sticker. Italic $ with thick black outline,
//    on bright green. Big appeal for GenZ social aesthetics.
// =========================================================================
func stickerDollar() {
    let ctx = makeContext()

    // Bright green base
    let g = CGGradient(colorsSpace: cs,
        colors: [brandLight, brand] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

    // Thick black outline frame for sticker effect (rounded rect)
    let inset = size * 0.03
    let outline = CGPath(roundedRect: CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2),
                         cornerWidth: size * 0.18, cornerHeight: size * 0.18, transform: nil)
    ctx.addPath(outline)
    ctx.setStrokeColor(ink)
    ctx.setLineWidth(size * 0.045)
    ctx.strokePath()

    // Big italic $
    let pointSize = size * 0.78
    let baseFont = NSFont.systemFont(ofSize: pointSize, weight: .black)
    let descriptor = baseFont.fontDescriptor.withSymbolicTraits([.italic, .bold])
    let font = NSFont(descriptor: descriptor, size: pointSize) ?? baseFont

    // Two-pass: thick black stroke behind, white fill on top
    let para = NSMutableParagraphStyle(); para.alignment = .center

    // Stroke
    let strokeAttrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
        .strokeColor: NSColor.black,
        .strokeWidth: -8,   // negative = stroke + fill
        .paragraphStyle: para,
    ]
    let strokeStr = NSAttributedString(string: "$", attributes: strokeAttrs)
    let line = CTLineCreateWithAttributedString(strokeStr)
    let bounds = CTLineGetImageBounds(line, ctx)
    let textY = (size - bounds.height) / 2 - bounds.origin.y
    let textX = (size - bounds.width) / 2 - bounds.origin.x
    ctx.textPosition = CGPoint(x: textX, y: textY)
    CTLineDraw(line, ctx)

    // Sparkles
    for (x, y, r) in [(0.18, 0.85, 0.026), (0.84, 0.18, 0.020), (0.20, 0.20, 0.014)] {
        let p = CGPoint(x: size * CGFloat(x), y: size * CGFloat(y))
        filledCircle(ctx, at: p, r: size * CGFloat(r), color: rgb(0xFF, 0xFF, 0xFF, 0.85))
    }

    savePNG(ctx, named: "03_sticker_dollar")
}

// =========================================================================
// 4. GRADIENT BLOB, modern organic blob shape with $ inside. Aesthetic.
// =========================================================================
func gradientBlob() {
    let ctx = makeContext()

    // Cream bg
    ctx.setFillColor(rgb(0xFA, 0xFA, 0xFA))
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

    // Blob path, organic asymmetric shape
    let cx = size * 0.5, cy = size * 0.5
    let blob = CGMutablePath()
    blob.move(to: CGPoint(x: cx + size * 0.35, y: cy))
    blob.addCurve(to: CGPoint(x: cx, y: cy + size * 0.36),
                  control1: CGPoint(x: cx + size * 0.36, y: cy + size * 0.20),
                  control2: CGPoint(x: cx + size * 0.18, y: cy + size * 0.40))
    blob.addCurve(to: CGPoint(x: cx - size * 0.36, y: cy),
                  control1: CGPoint(x: cx - size * 0.20, y: cy + size * 0.34),
                  control2: CGPoint(x: cx - size * 0.40, y: cy + size * 0.20))
    blob.addCurve(to: CGPoint(x: cx, y: cy - size * 0.34),
                  control1: CGPoint(x: cx - size * 0.34, y: cy - size * 0.22),
                  control2: CGPoint(x: cx - size * 0.18, y: cy - size * 0.36))
    blob.addCurve(to: CGPoint(x: cx + size * 0.35, y: cy),
                  control1: CGPoint(x: cx + size * 0.18, y: cy - size * 0.32),
                  control2: CGPoint(x: cx + size * 0.36, y: cy - size * 0.20))
    blob.closeSubpath()

    // Fill with diagonal gradient
    ctx.saveGState()
    ctx.addPath(blob); ctx.clip()
    let bg = CGGradient(colorsSpace: cs,
        colors: [brandLight, brand, brandDeep] as CFArray, locations: [0, 0.55, 1])!
    let bb = blob.boundingBoxOfPath
    ctx.drawLinearGradient(bg,
        start: CGPoint(x: bb.minX, y: bb.maxY),
        end: CGPoint(x: bb.maxX, y: bb.minY), options: [])
    ctx.restoreGState()

    // White $ in the center
    let pointSize = size * 0.55
    let baseFont = NSFont.systemFont(ofSize: pointSize, weight: .black)
    let font = NSFont(descriptor: baseFont.fontDescriptor.withSymbolicTraits([.italic, .bold]), size: pointSize) ?? baseFont
    let para = NSMutableParagraphStyle(); para.alignment = .center
    let str = NSAttributedString(string: "$", attributes: [
        .font: font, .foregroundColor: NSColor.white, .paragraphStyle: para
    ])
    let line = CTLineCreateWithAttributedString(str)
    let bounds = CTLineGetImageBounds(line, ctx)
    ctx.textPosition = CGPoint(x: cx - bounds.width / 2 - bounds.origin.x,
                               y: cy - bounds.height / 2 - bounds.origin.y)
    CTLineDraw(line, ctx)

    // Floating mini blobs
    for (x, y, r) in [(0.18, 0.78, 0.040), (0.85, 0.22, 0.030), (0.78, 0.85, 0.022)] {
        let p = CGPoint(x: size * CGFloat(x), y: size * CGFloat(y))
        filledCircle(ctx, at: p, r: size * CGFloat(r), color: rgb(0x04, 0xBA, 0x74, 0.55))
    }

    savePNG(ctx, named: "04_gradient_blob")
}

// =========================================================================
// 5. MINIMAL C, Lowercase typographic mark. Apple Card-style minimal.
// =========================================================================
func minimalC() {
    let ctx = makeContext()

    // Soft cream gradient background
    let bgGrad = CGGradient(colorsSpace: cs,
        colors: [rgb(0xFD, 0xFC, 0xF8), rgb(0xF0, 0xF6, 0xF1)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bgGrad, start: .zero, end: CGPoint(x: size, y: size), options: [])

    // Subtle gold radial top-right
    let halo = CGGradient(colorsSpace: cs,
        colors: [rgb(0xFF, 0xD2, 0x7A, 0.20), rgb(0xFF, 0xD2, 0x7A, 0.0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(halo,
        startCenter: CGPoint(x: size * 0.85, y: size * 0.15), startRadius: 0,
        endCenter: CGPoint(x: size * 0.85, y: size * 0.15), endRadius: size * 0.55, options: [])

    // Big "c" in display weight
    let pointSize = size * 0.85
    let baseFont = NSFont.systemFont(ofSize: pointSize, weight: .heavy)
    // Italic for more character
    let font = NSFont(descriptor: baseFont.fontDescriptor.withSymbolicTraits([.italic]), size: pointSize) ?? baseFont
    let para = NSMutableParagraphStyle(); para.alignment = .center

    // Gradient fill via mask
    ctx.saveGState()
    let textAttrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: NSColor.black, .paragraphStyle: para,
    ]
    let str = NSAttributedString(string: "c", attributes: textAttrs)
    let line = CTLineCreateWithAttributedString(str)
    let bounds = CTLineGetImageBounds(line, ctx)
    let textX = size / 2 - bounds.width / 2 - bounds.origin.x
    let textY = size / 2 - bounds.height / 2 - bounds.origin.y

    // Get glyph path
    let runs = CTLineGetGlyphRuns(line) as! [CTRun]
    let path = CGMutablePath()
    for run in runs {
        let runFont = unsafeBitCast(CFDictionaryGetValue(CTRunGetAttributes(run), Unmanaged.passUnretained(kCTFontAttributeName).toOpaque()), to: CTFont.self)
        let glyphCount = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: glyphCount)
        var positions = [CGPoint](repeating: .zero, count: glyphCount)
        CTRunGetGlyphs(run, CFRangeMake(0, glyphCount), &glyphs)
        CTRunGetPositions(run, CFRangeMake(0, glyphCount), &positions)
        for i in 0..<glyphCount {
            if let glyphPath = CTFontCreatePathForGlyph(runFont, glyphs[i], nil) {
                var transform = CGAffineTransform(translationX: textX + positions[i].x,
                                                  y: textY + positions[i].y)
                path.addPath(glyphPath, transform: transform)
            }
        }
    }
    ctx.addPath(path); ctx.clip()
    let textGrad = CGGradient(colorsSpace: cs,
        colors: [brandLight, brand, brandDeep] as CFArray, locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(textGrad,
        start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])
    ctx.restoreGState()

    savePNG(ctx, named: "05_minimal_c")
}

// =========================================================================
// 6. PIGGY DUO, minimal 2D piggy bank silhouette + coin. Cute + modern.
// =========================================================================
func piggyMinimal() {
    let ctx = makeContext()

    ctx.setFillColor(rgb(0xFA, 0xFA, 0xFA))
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

    let halo = CGGradient(colorsSpace: cs,
        colors: [rgb(0x04, 0xBA, 0x74, 0.22), rgb(0x04, 0xBA, 0x74, 0.0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(halo,
        startCenter: CGPoint(x: size * 0.5, y: size * 0.5), startRadius: 0,
        endCenter: CGPoint(x: size * 0.5, y: size * 0.5), endRadius: size * 0.45, options: [])

    // Piggy body, rounded oval with ear + leg + tail
    let bodyRect = CGRect(x: size * 0.20, y: size * 0.30, width: size * 0.60, height: size * 0.40)
    let body = CGPath(roundedRect: bodyRect, cornerWidth: size * 0.18, cornerHeight: size * 0.18, transform: nil)
    ctx.saveGState()
    ctx.addPath(body); ctx.clip()
    let bodyGrad = CGGradient(colorsSpace: cs,
        colors: [brandLight, brand] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bodyGrad,
        start: CGPoint(x: bodyRect.minX, y: bodyRect.maxY),
        end: CGPoint(x: bodyRect.maxX, y: bodyRect.minY), options: [])
    ctx.restoreGState()
    ctx.addPath(body)
    ctx.setStrokeColor(brandDeep); ctx.setLineWidth(size * 0.014); ctx.strokePath()

    // Snout, small rounded rectangle on right
    let snoutRect = CGRect(x: size * 0.74, y: size * 0.43, width: size * 0.13, height: size * 0.13)
    let snout = CGPath(roundedRect: snoutRect, cornerWidth: size * 0.040, cornerHeight: size * 0.040, transform: nil)
    ctx.addPath(snout)
    ctx.setFillColor(brandDeep); ctx.fillPath()
    // Nostrils
    filledCircle(ctx, at: CGPoint(x: snoutRect.midX - size * 0.022, y: snoutRect.midY),
                 r: size * 0.010, color: rgb(0xFF, 0xFF, 0xFF))
    filledCircle(ctx, at: CGPoint(x: snoutRect.midX + size * 0.022, y: snoutRect.midY),
                 r: size * 0.010, color: rgb(0xFF, 0xFF, 0xFF))

    // Eye
    filledCircle(ctx, at: CGPoint(x: size * 0.62, y: size * 0.55),
                 r: size * 0.022, color: rgb(0x1A, 0x2A, 0x22))
    filledCircle(ctx, at: CGPoint(x: size * 0.625, y: size * 0.555),
                 r: size * 0.008, color: rgb(0xFF, 0xFF, 0xFF))

    // Ear (triangle)
    let ear = CGMutablePath()
    ear.move(to: CGPoint(x: size * 0.55, y: size * 0.70))
    ear.addLine(to: CGPoint(x: size * 0.62, y: size * 0.70))
    ear.addLine(to: CGPoint(x: size * 0.59, y: size * 0.78))
    ear.closeSubpath()
    ctx.addPath(ear)
    ctx.setFillColor(brandDeep); ctx.fillPath()

    // Coin slot on top
    let slot = CGRect(x: size * 0.36, y: size * 0.685, width: size * 0.16, height: size * 0.020)
    ctx.addPath(CGPath(roundedRect: slot, cornerWidth: size * 0.010, cornerHeight: size * 0.010, transform: nil))
    ctx.setFillColor(brandDeep); ctx.fillPath()

    // Legs (two short rounded rects below)
    for x in [size * 0.30, size * 0.62] {
        let leg = CGRect(x: x, y: size * 0.22, width: size * 0.08, height: size * 0.10)
        ctx.addPath(CGPath(roundedRect: leg, cornerWidth: size * 0.020, cornerHeight: size * 0.020, transform: nil))
        ctx.setFillColor(brand); ctx.fillPath()
        ctx.addPath(CGPath(roundedRect: leg, cornerWidth: size * 0.020, cornerHeight: size * 0.020, transform: nil))
        ctx.setStrokeColor(brandDeep); ctx.setLineWidth(size * 0.010); ctx.strokePath()
    }

    // Floating coin above (gold)
    let coin = CGRect(x: size * 0.32, y: size * 0.78, width: size * 0.14, height: size * 0.14)
    ctx.addPath(CGPath(ellipseIn: coin, transform: nil))
    ctx.setFillColor(rgb(0xFF, 0xC8, 0x4D)); ctx.fillPath()
    ctx.addPath(CGPath(ellipseIn: coin, transform: nil))
    ctx.setStrokeColor(rgb(0xC8, 0x8A, 0x1F)); ctx.setLineWidth(size * 0.010); ctx.strokePath()
    // $ on coin
    let pointSize = size * 0.085
    let baseFont = NSFont.systemFont(ofSize: pointSize, weight: .black)
    let font = NSFont(descriptor: baseFont.fontDescriptor.withSymbolicTraits([.italic, .bold]), size: pointSize) ?? baseFont
    let para = NSMutableParagraphStyle(); para.alignment = .center
    let str = NSAttributedString(string: "$", attributes: [
        .font: font, .foregroundColor: NSColor(srgbRed: 0xC8/255, green: 0x8A/255, blue: 0x1F/255, alpha: 1),
        .paragraphStyle: para])
    let line = CTLineCreateWithAttributedString(str)
    let bounds = CTLineGetImageBounds(line, ctx)
    ctx.textPosition = CGPoint(x: coin.midX - bounds.width / 2 - bounds.origin.x,
                               y: coin.midY - bounds.height / 2 - bounds.origin.y)
    CTLineDraw(line, ctx)

    savePNG(ctx, named: "06_piggy_minimal")
}

leafMascot()
coinCharacter()
stickerDollar()
gradientBlob()
minimalC()
piggyMinimal()

print("\nAll options saved to: \(outDir.path)")
print("Pick one and copy to Cashie/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
