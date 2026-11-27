// Draws the 1024px app icon: an e-paper panel in a dark frame, with a 1-bit dithered dashboard.
// `make` reruns this whenever it changes and turns icon/AppIcon-1024.png into the app icon.
import AppKit

let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ink = NSColor(srgbRed: 0.10, green: 0.10, blue: 0.11, alpha: 1)
let paper = NSColor(srgbRed: 0.93, green: 0.92, blue: 0.89, alpha: 1)

// macOS icon grid: 824pt body centred on the 1024 canvas, with the standard soft drop shadow.
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.shadowBlurRadius = 28
shadow.set()
NSColor(srgbRed: 0.17, green: 0.17, blue: 0.18, alpha: 1).setFill()
NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185).fill()
NSGraphicsContext.restoreGraphicsState()

let screen = body.insetBy(dx: 88, dy: 88)
paper.setFill()
NSBezierPath(roundedRect: screen, xRadius: 36, yRadius: 36).fill()

// 1-bit checkerboard, the way an e-ink panel fakes grey.
func dither(_ rect: NSRect, cell: CGFloat = 8) {
    ink.setFill()
    var y = rect.minY
    while y < rect.maxY {
        var x = rect.minX + (Int((y - rect.minY) / cell) % 2 == 0 ? 0 : cell)
        while x < rect.maxX {
            NSRect(x: x, y: y, width: min(cell, rect.maxX - x), height: min(cell, rect.maxY - y)).fill()
            x += cell * 2
        }
        y += cell
    }
}

func bar(y: CGFloat, filled: CGFloat) {
    let track = NSRect(x: screen.minX + 56, y: y, width: 300, height: 44)
    ink.setStroke()
    let outline = NSBezierPath(roundedRect: track, xRadius: 22, yRadius: 22)
    outline.lineWidth = 8
    outline.stroke()
    NSGraphicsContext.saveGraphicsState()
    outline.addClip()
    ink.setFill()
    NSRect(x: track.minX, y: track.minY, width: track.width * filled, height: track.height).fill()
    dither(NSRect(x: track.minX + track.width * filled, y: track.minY, width: track.width * (1 - filled), height: track.height))
    NSGraphicsContext.restoreGraphicsState()
}

// Left column: three progress bars. Right column: a sun over a dithered block.
bar(y: screen.maxY - 150, filled: 0.35)
bar(y: screen.maxY - 270, filled: 0.75)
bar(y: screen.maxY - 390, filled: 0.6)

let sun = NSPoint(x: screen.maxX - 140, y: screen.maxY - 248)  // level with the middle bar
ink.setFill()
NSBezierPath(ovalIn: NSRect(x: sun.x - 52, y: sun.y - 52, width: 104, height: 104)).fill()
ink.setStroke()
for i in 0..<8 {
    let a = CGFloat(i) * .pi / 4
    let ray = NSBezierPath()
    ray.move(to: NSPoint(x: sun.x + cos(a) * 78, y: sun.y + sin(a) * 78))
    ray.line(to: NSPoint(x: sun.x + cos(a) * 110, y: sun.y + sin(a) * 110))
    ray.lineWidth = 16
    ray.lineCapStyle = .round
    ray.stroke()
}

let block = NSRect(x: screen.minX + 56, y: screen.minY + 56, width: screen.width - 112, height: 92)
NSGraphicsContext.saveGraphicsState()
NSBezierPath(roundedRect: block, xRadius: 14, yRadius: 14).addClip()
dither(block)
NSGraphicsContext.restoreGraphicsState()

try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
