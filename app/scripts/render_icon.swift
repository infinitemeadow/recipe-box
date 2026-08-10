import AppKit

// Renders the Recipe Box app icon: the kanji 食 ("food / to eat") in muted ochre
// on a warm dark squircle, matching the app's palette. Run via:
//   swift render_icon.swift <output.iconset dir>

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let kanji = "食"
let bg = NSColor(srgbRed: 0x24/255.0, green: 0x1E/255.0, blue: 0x17/255.0, alpha: 1)
let amber = NSColor(srgbRed: 0xC8/255.0, green: 0x9D/255.0, blue: 0x61/255.0, alpha: 1)

func render(pixel: Int, to path: String) {
    let size = CGFloat(pixel)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixel, pixelsHigh: pixel,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return }
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    NSColor.clear.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()

    // squircle-ish rounded rect with a small transparent margin
    let margin = size * 0.085
    let inner = NSRect(x: margin, y: margin, width: size - 2 * margin, height: size - 2 * margin)
    let radius = inner.width * 0.2237
    let plate = NSBezierPath(roundedRect: inner, xRadius: radius, yRadius: radius)
    bg.setFill()
    plate.fill()

    // warm rim
    amber.withAlphaComponent(0.22).setStroke()
    plate.lineWidth = max(1, size * 0.012)
    plate.stroke()

    // kanji
    let fontSize = inner.height * 0.6
    let font = NSFont(name: "HiraginoSans-W6", size: fontSize)
        ?? NSFont(name: "Hiragino Sans", size: fontSize)
        ?? NSFont.systemFont(ofSize: fontSize, weight: .semibold)
    let para = NSMutableParagraphStyle()
    para.alignment = .center
    let str = NSAttributedString(string: kanji, attributes: [
        .font: font, .foregroundColor: amber, .paragraphStyle: para,
    ])
    let textSize = str.size()
    let point = NSPoint(
        x: inner.midX - textSize.width / 2,
        y: inner.midY - textSize.height / 2 + inner.height * 0.01
    )
    str.draw(at: point)

    NSGraphicsContext.restoreGraphicsState()

    if let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: URL(fileURLWithPath: path))
    }
}

let specs: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, px) in specs { render(pixel: px, to: outDir + "/" + name) }
print("rendered \(specs.count) icon sizes to \(outDir)")
