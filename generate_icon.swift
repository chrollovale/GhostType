import AppKit
import CoreGraphics

let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Failed to create icon drawing context")
}

context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)
context.setFillColor(NSColor(calibratedRed: 0.94, green: 0.93, blue: 0.91, alpha: 1).cgColor)
context.fill(CGRect(x: 0, y: 0, width: size, height: size))

let tile = CGRect(x: 88, y: 88, width: 848, height: 848)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 176, cornerHeight: 176, transform: nil)
context.addPath(tilePath)
context.setFillColor(NSColor(calibratedRed: 0.99, green: 0.985, blue: 0.975, alpha: 1).cgColor)
context.fillPath()

context.addPath(tilePath)
context.setLineWidth(12)
context.setStrokeColor(NSColor(calibratedRed: 0.82, green: 0.81, blue: 0.78, alpha: 1).cgColor)
context.strokePath()

let dotSize: CGFloat = 84
let pitch: CGFloat = 150
let centers: [CGFloat] = [512 - pitch, 512, 512 + pitch]
let ink = NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.08, alpha: 1).cgColor
let blue = NSColor(calibratedRed: 0.22, green: 0.34, blue: 0.98, alpha: 1).cgColor

for row in 0..<3 {
    for column in 0..<3 {
        let center = CGPoint(x: centers[column], y: centers[row])
        let dot = CGRect(
            x: center.x - dotSize / 2,
            y: center.y - dotSize / 2,
            width: dotSize,
            height: dotSize
        )
        context.addEllipse(in: dot)
        context.setFillColor(row == 1 && column == 1 ? blue : ink)
        context.fillPath()
    }
}

guard let cgImage = context.makeImage() else {
    fatalError("Failed to render icon")
}
let bitmap = NSBitmapImageRep(cgImage: cgImage)
guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Failed to encode icon PNG")
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
try pngData.write(to: URL(fileURLWithPath: outputPath))
print("Successfully generated GhostType icon at: \(outputPath)")
