// Генерирует .iconset для Focus Radio: сквиркл с тёплым градиентом
// + концентрические круги (радиоволны/фокус).
// Запуск: swift scripts/make-icon.swift <output.iconset>

import AppKit

let topColor    = NSColor(srgbRed: 1.00, green: 0.62, blue: 0.24, alpha: 1) // амбер, верх
let bottomColor = NSColor(srgbRed: 0.92, green: 0.34, blue: 0.14, alpha: 1) // бургерная тыква, низ

func drawIcon(px: Int) -> Data {
    let size = CGFloat(px)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Сквиркл с полем по краям, как у иконок macOS.
    let margin = size * 0.09
    let rect = NSRect(x: margin, y: margin, width: size - 2 * margin, height: size - 2 * margin)
    let corner = rect.width * 0.2237
    let plate = NSBezierPath(roundedRect: rect, xRadius: corner, yRadius: corner)
    NSGradient(starting: topColor, ending: bottomColor)!.draw(in: plate, angle: -90)

    // Концентрические круги — «радиоволны + фокус».
    let cx = size / 2, cy = size / 2
    NSColor.white.setStroke()
    NSColor.white.setFill()
    let strokeW = size * 0.06
    for r in [size * 0.32, size * 0.22, size * 0.12] {
        let ring = NSBezierPath(ovalIn: NSRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        ring.lineWidth = strokeW
        ring.stroke()
    }
    let dotR = size * 0.04
    NSBezierPath(ovalIn: NSRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2)).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("icon_16x16", 16),   ("icon_16x16@2x", 32),
    ("icon_32x32", 32),   ("icon_32x32@2x", 64),
    ("icon_128x128", 128),("icon_128x128@2x", 256),
    ("icon_256x256", 256),("icon_256x256@2x", 512),
    ("icon_512x512", 512),("icon_512x512@2x", 1024),
]
for (name, px) in sizes {
    try! drawIcon(px: px).write(to: URL(fileURLWithPath: "\(out)/\(name).png"))
}
print("wrote \(sizes.count) PNGs to \(out)")
