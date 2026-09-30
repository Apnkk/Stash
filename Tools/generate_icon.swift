#!/usr/bin/swift
// Génère toutes les tailles d'icône de l'app Stash À PARTIR de l'image source
// AppIcon-1024.png fournie (redimensionnement), au lieu de dessiner un placeholder.
// Décodage via ImageIO + rendu CoreGraphics uniquement : aucune dépendance à AppKit
// ni à une session graphique, donc fiable sur un runner CI macOS headless.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Chemin de l'image source 1024x1024 (obligatoire).
let sourcePath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon-1024.png"

guard FileManager.default.fileExists(atPath: sourcePath) else {
    FileHandle.standardError.write("Image source introuvable : \(sourcePath)\n".data(using: .utf8)!)
    exit(1)
}

// Charge l'image source en CGImage via ImageIO (pas d'AppKit).
guard let srcData = FileManager.default.contents(atPath: sourcePath) as CFData?,
      let imageSource = CGImageSourceCreateWithData(srcData, nil),
      let sourceImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
    FileHandle.standardError.write("Impossible de décoder l'image source : \(sourcePath)\n".data(using: .utf8)!)
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
    ctx.setFillColor(CGColor(colorSpace: colorSpace, components: [0.18, 0.15, 0.45, 1.0])!)
    ctx.fill(rect)

    // Dessine l'image source redimensionnée pour remplir toute l'icône.
    ctx.interpolationQuality = .high
    ctx.draw(sourceImage, in: rect)

    return ctx.makeImage()
}

// Écrit un CGImage en PNG via ImageIO (pas d'AppKit).
func writePNG(_ image: CGImage, to path: String) -> Bool {
    let url = URL(fileURLWithPath: path) as CFURL
    let pngType: CFString
    if #available(macOS 11.0, *) {
        pngType = UTType.png.identifier as CFString
    } else {
        pngType = "public.png" as CFString
    }
    guard let dest = CGImageDestinationCreateWithURL(url, pngType, 1, nil) else {
        FileHandle.standardError.write("Impossible de créer la destination PNG (\(path)).\n".data(using: .utf8)!)
        return false
    }
    CGImageDestinationAddImage(dest, image, nil)
    if !CGImageDestinationFinalize(dest) {
        FileHandle.standardError.write("Erreur d'écriture PNG (\(path)).\n".data(using: .utf8)!)
        return false
    }
    return true
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
