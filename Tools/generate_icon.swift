#!/usr/bin/swift
// Génère toutes les tailles d'icône de l'app Stash À PARTIR de l'image source
// AppIcon-1024.png fournie (redimensionnement), au lieu de dessiner un placeholder.
// Utilisé par le workflow CI (macOS) avant la compilation.
import AppKit
import CoreGraphics

// Chemin de l'image source 1024x1024 (obligatoire).
let sourcePath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon-1024.png"

guard FileManager.default.fileExists(atPath: sourcePath) else {
    FileHandle.standardError.write("Image source introuvable : \(sourcePath)\n".data(using: .utf8)!)
    exit(1)
}

// Charge l'image source en CGImage.
guard let srcData = FileManager.default.contents(atPath: sourcePath),
      let srcRep = NSBitmapImageRep(data: srcData),
      let sourceImage = srcRep.cgImage else {
    FileHandle.standardError.write("Impossible de lire l'image source : \(sourcePath)\n".data(using: .utf8)!)
    exit(1)
}

// Redimensionne l'image source vers une dimension donnée, en OPAQUE (sans alpha).
// Les icônes iOS doivent être opaques, sinon actool les rejette et aucune icône n'apparaît.
func renderIcon(pixels: Int) -> CGImage? {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let ctx = CGContext(
            data: nil,
            width: pixels,
            height: pixels,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
          ) else {
        return nil
    }

    let s = CGFloat(pixels)
    let rect = CGRect(x: 0, y: 0, width: s, height: s)

    // Fond opaque de sécurité (au cas où la source aurait de la transparence).
    ctx.setFillColor(CGColor(red: 0.18, green: 0.15, blue: 0.45, alpha: 1.0))
    ctx.fill(rect)

    // Dessine l'image source redimensionnée pour remplir toute l'icône.
    ctx.interpolationQuality = .high
    ctx.draw(sourceImage, in: rect)

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
let outputDir = (sourcePath as NSString).deletingLastPathComponent
func out(_ name: String) -> String {
    outputDir.isEmpty ? name : "\(outputDir)/\(name)"
}

// Toutes les tailles PNG référencées par Contents.json (nom -> pixels).
// Le 1024 n'est PAS régénéré : on garde l'image source telle quelle.
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
    ("AppIcon-180.png", 180)
]

for (name, px) in variants {
    guard let img = renderIcon(pixels: px) else {
        FileHandle.standardError.write("Impossible de générer l'icône \(px)px.\n".data(using: .utf8)!)
        exit(1)
    }
    if !writePNG(img, to: out(name)) {
        exit(1)
    }
    print("Icône écrite (depuis la source) : \(out(name)) (\(px)x\(px))")
}
print("Icône source conservée : \(sourcePath) (1024x1024)")
exit(0)
