import AppKit
import CoreGraphics

let size: CGFloat = 1024.0
let image = NSImage(size: NSSize(width: size, height: size))

image.lockFocus()
guard let context = NSGraphicsContext.current?.cgContext else {
    fatalError("Failed to get graphics context")
}

// Enable anti-aliasing
context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)

// 1. Draw Background macOS Squircle
let squircleRect = CGRect(x: 80, y: 80, width: 864, height: 864)
let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: 200, cornerHeight: 200, transform: nil)

context.saveGState()
context.addPath(squirclePath)
context.clip()

// Background dark gradient (deep navy / obsidian)
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bgColors = [
    NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.16, alpha: 1.0).cgColor,
    NSColor(calibratedRed: 0.04, green: 0.05, blue: 0.08, alpha: 1.0).cgColor
] as CFArray
if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) {
    context.drawLinearGradient(bgGradient, start: CGPoint(x: 512, y: 944), end: CGPoint(x: 512, y: 80), options: [])
}
context.restoreGState()

// Subtle inner border / border stroke
context.saveGState()
context.addPath(squirclePath)
context.setLineWidth(6.0)
context.setStrokeColor(NSColor(calibratedWhite: 1.0, alpha: 0.12).cgColor)
context.strokePath()
context.restoreGState()

// 2. Keycap Bevel (3D minimal elevation)
let keycapRect = CGRect(x: 200, y: 220, width: 624, height: 600)
let keycapPath = CGPath(roundedRect: keycapRect, cornerWidth: 90, cornerHeight: 90, transform: nil)

context.saveGState()
// Shadow under keycap
context.setShadow(offset: CGSize(width: 0, height: -20), blur: 30, color: NSColor(calibratedWhite: 0.0, alpha: 0.5).cgColor)
context.addPath(keycapPath)
context.setFillColor(NSColor(calibratedRed: 0.14, green: 0.16, blue: 0.22, alpha: 1.0).cgColor)
context.fillPath()
context.restoreGState()

// Top face of the keycap
let topFaceRect = CGRect(x: 225, y: 275, width: 574, height: 520)
let topFacePath = CGPath(roundedRect: topFaceRect, cornerWidth: 70, cornerHeight: 70, transform: nil)

context.saveGState()
context.addPath(topFacePath)
context.clip()

let keyColors = [
    NSColor(calibratedRed: 0.19, green: 0.22, blue: 0.30, alpha: 1.0).cgColor,
    NSColor(calibratedRed: 0.12, green: 0.13, blue: 0.19, alpha: 1.0).cgColor
] as CFArray
if let keyGradient = CGGradient(colorsSpace: colorSpace, colors: keyColors, locations: [0.0, 1.0]) {
    context.drawLinearGradient(keyGradient, start: CGPoint(x: 512, y: 795), end: CGPoint(x: 512, y: 275), options: [])
}
context.restoreGState()

// Keycap border rim
context.saveGState()
context.addPath(topFacePath)
context.setLineWidth(3.0)
context.setStrokeColor(NSColor(calibratedWhite: 1.0, alpha: 0.15).cgColor)
context.strokePath()
context.restoreGState()

// 3. Central Injector Glyph: Minimal chevron ">" + downward injection bolt "⚡ / ↓"
// Glowing Cyan-to-Purple Gradient
let glowColors = [
    NSColor(calibratedRed: 0.0, green: 0.95, blue: 0.90, alpha: 1.0).cgColor,  // Electric cyan
    NSColor(calibratedRed: 0.35, green: 0.45, blue: 1.0, alpha: 1.0).cgColor   // Royal blue/violet
] as CFArray
let glowGradient = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0])!

// Draw glowing Terminal Chevron `>`
let chevron = CGMutablePath()
chevron.move(to: CGPoint(x: 340, y: 640))
chevron.addLine(to: CGPoint(x: 430, y: 540))
chevron.addLine(to: CGPoint(x: 340, y: 440))

context.saveGState()
context.setShadow(offset: .zero, blur: 24, color: NSColor(calibratedRed: 0.0, green: 0.95, blue: 0.90, alpha: 0.6).cgColor)
context.addPath(chevron)
context.setLineCap(.round)
context.setLineJoin(.round)
context.setLineWidth(42.0)
context.replacePathWithStrokedPath()
context.clip()
context.drawLinearGradient(glowGradient, start: CGPoint(x: 340, y: 640), end: CGPoint(x: 430, y: 440), options: [])
context.restoreGState()

// Draw Downward Injector Needle / Arrow Beam
let beam = CGMutablePath()
beam.move(to: CGPoint(x: 570, y: 660))
beam.addLine(to: CGPoint(x: 570, y: 400))
// Arrow head
beam.addLine(to: CGPoint(x: 510, y: 460))
beam.move(to: CGPoint(x: 570, y: 400))
beam.addLine(to: CGPoint(x: 630, y: 460))

context.saveGState()
context.setShadow(offset: .zero, blur: 28, color: NSColor(calibratedRed: 0.2, green: 0.7, blue: 1.0, alpha: 0.7).cgColor)
context.addPath(beam)
context.setLineCap(.round)
context.setLineJoin(.round)
context.setLineWidth(42.0)
context.replacePathWithStrokedPath()
context.clip()
context.drawLinearGradient(glowGradient, start: CGPoint(x: 570, y: 660), end: CGPoint(x: 570, y: 400), options: [])
context.restoreGState()

// Terminal cursor dot / pill under injector
let pillRect = CGRect(x: 540, y: 320, width: 60, height: 16)
let pillPath = CGPath(roundedRect: pillRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
context.saveGState()
context.setShadow(offset: .zero, blur: 16, color: NSColor(calibratedRed: 0.0, green: 0.95, blue: 0.90, alpha: 0.8).cgColor)
context.addPath(pillPath)
context.setFillColor(NSColor(calibratedRed: 0.0, green: 0.95, blue: 0.90, alpha: 0.9).cgColor)
context.fillPath()
context.restoreGState()

image.unlockFocus()

// Save to PNG
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Failed to convert image to PNG")
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
try pngData.write(to: URL(fileURLWithPath: outputPath))
print("Successfully generated icon at: \(outputPath)")
