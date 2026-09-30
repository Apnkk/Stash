#!/usr/bin/swift
// Génère l'icône de l'app Stash : un PNG 1024x1024 avec un dégradé et un "S".
// Utilisé par le workflow CI (macOS) avant la compilation.
import AppKit
import CoreGraphics

let size = 1024
let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon-1024.png"

// Fonction de rendu de l'icône à une dimension donnée (toujours OPAQUE, sans alpha).
func renderIcon(pixels: Int) -> CGImage? {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let ctx = CGContext(
            data: nil,
            width: pixels,
            height: pixels,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            // Les icônes iOS doivent être OPAQUES (pas de canal alpha), sinon actool
            // les rejette et aucune icône n'apparaît. noneSkipLast = pas d'alpha.
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
          ) else {
        return nil
    }

    let s = CGFloat(pixels)
    let rect = CGRect(x: 0, y: 0, width: s, height: s)

    // Remplit d'abord tout le fond en opaque (sécurité pour éviter toute zone transparente).
    ctx.setFillColor(CGColor(red: 0.18, green: 0.15, blue: 0.45, alpha: 1.0))
    ctx.fill(rect)

    // Fond en dégradé (violet -> indigo).
    let colors = [
        CGColor(red: 0.42, green: 0.28, blue: 0.85, alpha: 1.0),
        CGColor(red: 0.18, green: 0.15, blue: 0.45, alpha: 1.0)
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: s),
            end: CGPoint(x: s, y: 0),
            options: []
        )
    }

    // Lettre "S" centrée, taille proportionnelle à l'icône.
    let nsImageRep = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsImageRep

    let letter = "S" as NSString
    let fontSize: CGFloat = s * 0.605
    let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white
    ]
    let textSize = letter.size(withAttributes: attributes)
    let textRect = CGRect(
        x: (s - textSize.width) / 2,
        y: (s - textSize.height) / 2,
        width: textSize.width,
        height: textSize.height
    )
    letter.draw(in: textRect, withAttributes: attributes)

    NSGraphicsContext.restoreGraphicsState()

    return ctx.makeImage()
}

func writePNG(_ image: CGImage, to path: String) -> Bool {
    let bitmapRep = NSBitmapImageRep(cgImage: image)
    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        return false
    }
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        return true
    } catch {
        FileHandle.standardError.write("Erreur d'écriture (\(path)) : \(error)\n".data(using: .utf8)!)
        return false
    }
}

// Dossier de sortie = dossier de l'appiconset (déduit du chemin du 1024 passé en argument).
let outputDir = (outputPath as NSString).deletingLastPathComponent
func out(_ name: String) -> String {
    outputDir.isEmpty ? name : "\(outputDir)/\(name)"
}

// Toutes les tailles PNG référencées par Contents.json (nom -> pixels).
let variants: [(String, Int)] = [
    ("AppIcon-20.png", 20),
    ("AppIcon-29.png", 29),
    ("AppIcon-40.png", 40),
    ("AppIcon-58.png", 58),
    ("AppIcon-60.png", 60),
    ("AppIcon-76.png", 76),
    ("AppIcon-80.png", 80),
    ("AppIcon-87.png", 87),
    ("AppIcon-120.png", 120),
    ("AppIcon-152.png", 152),
    ("AppIcon-167.png", 167),
    ("AppIcon-180.png", 180),
    ("AppIcon-1024.png", 1024)
]

for (name, px) in variants {
    guard let img = renderIcon(pixels: px) else {
        FileHandle.standardError.write("Impossible de générer l'icône \(px)px.\n".data(using: .utf8)!)
        exit(1)
    }
    if !writePNG(img, to: out(name)) {
        exit(1)
    }
    print("Icône écrite : \(out(name)) (\(px)x\(px))")
}
exit(0)

// --- Ancien chemin mono-taille (conservé mais non atteint) ---
guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
      ) else {
    FileHandle.standardError.write("Impossible de créer le contexte graphique.\n".data(using: .utf8)!)
    exit(1)
}

let rect = CGRect(x: 0, y: 0, width: size, height: size)

// Remplit d'abord tout le fond en opaque (sécurité pour éviter toute zone transparente).
ctx.setFillColor(CGColor(red: 0.18, green: 0.15, blue: 0.45, alpha: 1.0))
ctx.fill(rect)

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
