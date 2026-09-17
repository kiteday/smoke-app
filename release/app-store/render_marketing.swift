import AppKit

let canvasWidth = 1284
let canvasHeight = 2778
let source = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let firstLine = CommandLine.arguments[3]
let secondLine = CommandLine.arguments[4]
let subtitle = CommandLine.arguments[5]

guard let screenshot = NSImage(contentsOf: source),
      let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: canvasWidth,
        pixelsHigh: canvasHeight,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
      ) else { fatalError("이미지를 열 수 없습니다") }

func rect(x: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat) -> NSRect {
    NSRect(x: x, y: CGFloat(canvasHeight) - top - height, width: width, height: height)
}

let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

NSColor.black.setFill()
NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight).fill()

let glow = NSShadow()
glow.shadowColor = NSColor(calibratedRed: 1, green: 0.38, blue: 0.06, alpha: 0.38)
glow.shadowBlurRadius = 120
glow.shadowOffset = .zero
glow.set()
NSColor(calibratedRed: 0.32, green: 0.10, blue: 0.01, alpha: 0.5).setFill()
NSBezierPath(roundedRect: rect(x: 142, top: 760, width: 1000, height: 1860), xRadius: 64, yRadius: 64).fill()
NSGraphicsContext.restoreGraphicsState()
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

let centered = NSMutableParagraphStyle()
centered.alignment = .center
func drawText(_ text: String, top: CGFloat, size: CGFloat, color: NSColor, weight: NSFont.Weight) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: centered
    ]
    (text as NSString).draw(in: rect(x: 70, top: top, width: 1144, height: size * 1.35), withAttributes: attributes)
}

drawText(firstLine, top: 150, size: 88, color: .white, weight: .heavy)
drawText(secondLine, top: 270, size: 94, color: NSColor(calibratedRed: 1, green: 0.54, blue: 0.18, alpha: 1), weight: .heavy)
drawText(subtitle, top: 420, size: 38, color: NSColor(white: 0.72, alpha: 1), weight: .medium)

NSColor(calibratedRed: 1, green: 0.49, blue: 0.13, alpha: 0.85).setStroke()
let line = NSBezierPath()
line.lineWidth = 3
line.move(to: NSPoint(x: 390, y: CGFloat(canvasHeight) - 515))
line.line(to: NSPoint(x: 894, y: CGFloat(canvasHeight) - 515))
line.stroke()

let imageRect = rect(x: 182, top: 630, width: 920, height: 1991)
NSGraphicsContext.current?.cgContext.saveGState()
NSBezierPath(roundedRect: imageRect, xRadius: 58, yRadius: 58).addClip()
screenshot.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1)
NSGraphicsContext.current?.cgContext.restoreGState()

NSColor(calibratedRed: 1, green: 0.49, blue: 0.13, alpha: 0.5).setStroke()
let border = NSBezierPath(roundedRect: imageRect, xRadius: 58, yRadius: 58)
border.lineWidth = 2
border.stroke()

NSGraphicsContext.restoreGraphicsState()
guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.96]) else {
    fatalError("JPEG 생성 실패")
}
try data.write(to: output)
