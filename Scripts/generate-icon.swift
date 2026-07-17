// Membuat ikon app Waqtara secara programatik.
// Konsep: gnomon sundial (penentu waktu sholat dari bayangan matahari) + busur 5 titik
// (5 waktu sholat) di langit gradasi malam→fajar. Sengaja tanpa bulan sabit/kubah
// agar berbeda dari app sejenis.
// Jalankan: swift Scripts/generate-icon.swift <output-dir>

import AppKit
import CoreGraphics

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dist/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func drawIcon(size: CGFloat, context ctx: CGContext) {
    let s = size
    // Margin standar ikon macOS: konten ~82% kanvas.
    let inset = s * 0.09
    let rect = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let radius = rect.width * 0.2237   // squircle-ish macOS

    let rounded = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Bayangan halus di bawah ikon
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.008), blur: s * 0.02,
                  color: NSColor.black.withAlphaComponent(0.3).cgColor)
    ctx.addPath(rounded)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(rounded)
    ctx.clip()

    // Langit: indigo malam (atas) → ungu → amber fajar (horizon)
    let colors = [
        NSColor(calibratedRed: 0.10, green: 0.09, blue: 0.28, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.23, green: 0.13, blue: 0.38, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.72, green: 0.32, blue: 0.30, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.98, green: 0.65, blue: 0.28, alpha: 1).cgColor,
    ] as CFArray
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: colors, locations: [0, 0.45, 0.78, 1])!
    ctx.drawLinearGradient(grad,
                           start: CGPoint(x: rect.midX, y: rect.maxY),
                           end: CGPoint(x: rect.midX, y: rect.minY),
                           options: [])

    // Bidang tanah di bawah (horizon di ~30% tinggi) — warna hangat agar bayangan terbaca
    let horizonY = rect.minY + rect.height * 0.30
    ctx.setFillColor(NSColor(calibratedRed: 0.24, green: 0.16, blue: 0.26, alpha: 1).cgColor)
    ctx.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: horizonY - rect.minY))

    // Matahari rendah di horizon (menyembul, dengan glow)
    let sunR = rect.width * 0.085
    let sunC = CGPoint(x: rect.minX + rect.width * 0.26, y: horizonY)
    ctx.saveGState()
    ctx.clip(to: CGRect(x: rect.minX, y: horizonY, width: rect.width, height: rect.height))
    ctx.setShadow(offset: .zero, blur: sunR * 1.2,
                  color: NSColor(calibratedRed: 1.0, green: 0.8, blue: 0.4, alpha: 0.9).cgColor)
    ctx.setFillColor(NSColor(calibratedRed: 1.0, green: 0.9, blue: 0.6, alpha: 1).cgColor)
    ctx.fillEllipse(in: CGRect(x: sunC.x - sunR, y: sunC.y - sunR, width: sunR * 2, height: sunR * 2))
    ctx.restoreGState()

    // Busur 5 titik waktu sholat melintasi langit
    let arcCenter = CGPoint(x: rect.midX, y: horizonY)
    let arcR = rect.width * 0.34
    let dotR = rect.width * 0.028
    for i in 0..<5 {
        let angle = CGFloat.pi * (0.16 + 0.17 * CGFloat(i))  // 29°…151°
        let p = CGPoint(x: arcCenter.x + arcR * cos(angle), y: arcCenter.y + arcR * sin(angle))
        let active = i == 3  // satu titik "aktif" lebih besar & terang
        let r = active ? dotR * 1.7 : dotR
        ctx.setFillColor(NSColor(calibratedWhite: 1, alpha: active ? 1 : 0.55).cgColor)
        ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
    }

    // Piringan dial sundial: setengah elips di tanah dengan garis tick
    let dialC = CGPoint(x: rect.midX, y: horizonY)
    let dialRx = rect.width * 0.30
    let dialRy = rect.height * 0.115
    ctx.saveGState()
    ctx.translateBy(x: dialC.x, y: dialC.y)
    ctx.scaleBy(x: 1, y: dialRy / dialRx)
    ctx.setFillColor(NSColor(calibratedRed: 0.32, green: 0.22, blue: 0.33, alpha: 1).cgColor)
    let dialPath = CGMutablePath()
    dialPath.addArc(center: .zero, radius: dialRx, startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
    dialPath.closeSubpath()
    ctx.addPath(dialPath)
    ctx.fillPath()
    // Tick jam di piringan
    ctx.setStrokeColor(NSColor(calibratedWhite: 1, alpha: 0.35).cgColor)
    ctx.setLineWidth(rect.width * 0.012 * (dialRx / dialRy) / 8)
    for i in 0..<5 {
        let a = CGFloat.pi * (1.12 + 0.19 * CGFloat(i))
        ctx.move(to: CGPoint(x: cos(a) * dialRx * 0.55, y: sin(a) * dialRx * 0.55))
        ctx.addLine(to: CGPoint(x: cos(a) * dialRx * 0.85, y: sin(a) * dialRx * 0.85))
        ctx.strokePath()
    }
    ctx.restoreGState()

    // Gnomon: segitiga putih tegak di pusat dial
    let gw = rect.width * 0.085
    let gh = rect.height * 0.27
    let gx = dialC.x - gw / 2
    let gnomon = CGMutablePath()
    gnomon.move(to: CGPoint(x: gx, y: horizonY))
    gnomon.addLine(to: CGPoint(x: gx + gw, y: horizonY))
    gnomon.addLine(to: CGPoint(x: gx + gw, y: horizonY + gh))
    gnomon.closeSubpath()
    ctx.addPath(gnomon)
    ctx.setFillColor(NSColor(calibratedWhite: 0.98, alpha: 1).cgColor)
    ctx.fillPath()

    // Bayangan gnomon jatuh di piringan, menjauhi matahari (inti konsep: waktu dari bayangan)
    let shadow = CGMutablePath()
    let shadowLen = rect.width * 0.26
    shadow.move(to: CGPoint(x: gx + gw, y: horizonY))
    shadow.addLine(to: CGPoint(x: gx + gw + shadowLen, y: horizonY - dialRy * 0.55))
    shadow.addLine(to: CGPoint(x: gx + gw + shadowLen * 0.82, y: horizonY - dialRy * 0.8))
    shadow.addLine(to: CGPoint(x: gx, y: horizonY))
    shadow.closeSubpath()
    ctx.addPath(shadow)
    ctx.setFillColor(NSColor(calibratedWhite: 0, alpha: 0.42).cgColor)
    ctx.fillPath()

    ctx.restoreGState()
}

func writePNG(size: Int, scale: Int, name: String) {
    let pixels = size * scale
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    drawIcon(size: CGFloat(pixels), context: ctx.cgContext)
    NSGraphicsContext.current = nil
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
}

for (size, scale) in [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)] {
    let name = scale == 1 ? "icon_\(size)x\(size).png" : "icon_\(size)x\(size)@2x.png"
    writePNG(size: size, scale: scale, name: name)
}
print("iconset ditulis ke \(outDir)")
