#!/bin/bash
ICONSET="iconset"
mkdir -p "$ICONSET"

cat > /tmp/render_vol_icon.swift << 'SWIFT'
import Cocoa
let size = CGSize(width: 1024, height: 1024)
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else { exit(1) }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(calibratedRed: 0.09, green: 0.65, blue: 0.54, alpha: 1.0).setFill()
CGRect(origin: .zero, size: size).fill()
if let symbol = NSImage(systemSymbolName: "speaker.wave.3.fill", accessibilityDescription: nil) {
    let config = NSImage.SymbolConfiguration(pointSize: 520, weight: .medium)
    if let c = symbol.withSymbolConfiguration(config),
       let w = c.withSymbolConfiguration(NSImage.SymbolConfiguration(hierarchicalColor: .white)) {
        w.draw(in: CGRect(x: 222, y: 200, width: 580, height: 580))
    }
}
NSGraphicsContext.restoreGraphicsState()
if let data = rep.representation(using: .png, properties: [:]) {
    try? data.write(to: URL(fileURLWithPath: "/tmp/vol_icon_1024.png"))
}
SWIFT

swift /tmp/render_vol_icon.swift
SRC="/tmp/vol_icon_1024.png"
sips -z 16 16 "$SRC" --out "$ICONSET/icon_16x16.png"
sips -z 32 32 "$SRC" --out "$ICONSET/icon_16x16@2x.png"
sips -z 32 32 "$SRC" --out "$ICONSET/icon_32x32.png"
sips -z 64 64 "$SRC" --out "$ICONSET/icon_32x32@2x.png"
sips -z 128 128 "$SRC" --out "$ICONSET/icon_128x128.png"
sips -z 256 256 "$SRC" --out "$ICONSET/icon_128x128@2x.png"
sips -z 256 256 "$SRC" --out "$ICONSET/icon_256x256.png"
sips -z 512 512 "$SRC" --out "$ICONSET/icon_256x256@2x.png"
sips -z 512 512 "$SRC" --out "$ICONSET/icon_512x512.png"
cp "$SRC" "$ICONSET/icon_512x512@2x.png"
echo "Icon generated."
