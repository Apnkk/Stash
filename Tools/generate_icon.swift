#!/usr/bin/swift
// Génère l'icône de l'app Stash : un PNG 1024x1024 avec un dégradé et un "S".
// Utilisé par le workflow CI (macOS) avant la compilation.
import AppKit
import CoreGraphics

let size = 1024
let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon-1024.png"

guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ) else {
    FileHandle.standardError.write("Impossible de créer le contexte graphique.\n".data(using: .utf8)!)
    exit(1)
}

let rect = CGRect(x: 0, y: 0, width: size, height: size)

// Fond en dégradé (violet -> indigo).
let colors = [
    CGColor(red: 0.42, green: 0.28, blue: 0.85, alpha: 1.0),
    CGColor(red: 0.18, green: 0.15, blue: 0.45, alpha: 1.0)
] as CFArray
if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: size, y: 0),
        options: []
    )
}

// Lettre "S" centrée.
let nsImageRep = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = nsImageRep

let letter = "S" as NSString
let fontSize: CGFloat = 620
let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.white
]
let textSize = letter.size(withAttributes: attributes)
let textRect = CGRect(
    x: (CGFloat(size) - textSize.width) / 2,
    y: (CGFloat(size) - textSize.height) / 2,
    width: textSize.width,
    height: textSize.height
)
letter.draw(in: textRect, withAttributes: attributes)

NSGraphicsContext.restoreGraphicsState()

guard let cgImage = ctx.makeImage() else {
    FileHandle.standardError.write("Impossible de générer l'image.\n".data(using: .utf8)!)
    exit(1)
}

let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("Impossible d'encoder le PNG.\n".data(using: .utf8)!)
    exit(1)
}

do {
    try pngData.write(to: URL(fileURLWithPath: outputPath))
    print("Icône écrite : \(outputPath)")
} catch {
    FileHandle.standardError.write("Erreur d'écriture : \(error)\n".data(using: .utf8)!)
    exit(1)
}
