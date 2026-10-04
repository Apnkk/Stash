import SwiftUI
import VisionKit
import PhotosUI

/// Mode du scanner : code-barres (fidélité) ou texte de carte bancaire.
enum ScannerMode {
    case barcode
    case bankCard
}

/// Vue modale de numérisation via VisionKit (DataScannerViewController) avec fallback photothèque.
struct ScannerView: View {
    let mode: ScannerMode
    var onBarcodeScanned: ((String, BarcodeFormat) -> Void)?
    var onBankCardScanned: ((String, String?) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var pickedPhotoItem: PhotosPickerItem?
    @State private var scanError: String?
    @State private var isProcessingPhoto = false

    var isLiveScannerSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if isLiveScannerSupported {
                    LiveScannerRepresentable(
                        mode: mode,
                        onBarcode: { payload, format in
                            Haptics.success()
                            onBarcodeScanned?(payload, format)
                            dismiss()
                        },
                        onBankCard: { number, expiry in
                            Haptics.success()
                            onBankCardScanned?(number, expiry)
                            dismiss()
                        }
                    )
                    .ignoresSafeArea()

                    // Viseur visuel
                    scannerOverlay
                } else {
                    unsupportedCameraView
                }

                if isProcessingPhoto {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    ProgressView("Analyse de l'image…")
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .navigationTitle(mode == .bankCard ? "Scanner une carte bancaire" : "Scanner un code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    PhotosPicker(selection: $pickedPhotoItem, matching: .images) {
                        Image(systemName: "photo.on.rectangle")
                    }
                    .accessibilityLabel("Choisir une photo")
                }
            }
            .onChange(of: pickedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task { await handlePickedPhoto(newItem) }
            }
        }
    }

    private var scannerOverlay: some View {
        VStack {
            Text(mode == .bankCard ? "Cadre le recto de ta carte bancaire" : "Cadre le code-barres ou QR code")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.top, 24)

            Spacer()

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.stashRed.opacity(0.8), lineWidth: 2)
                .frame(width: 290, height: mode == .bankCard ? 180 : 180)
                .background(Color.white.opacity(0.04))

            Spacer()

            if let scanError {
                Text(scanError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
            }
        }
    }

    private var unsupportedCameraView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Caméra indisponible")
                .font(.headline)
            Text("Le scanner direct n'est pas disponible sur cet appareil. Tu peux importer une capture d'écran depuis ta photothèque.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            PhotosPicker(selection: $pickedPhotoItem, matching: .images) {
                Label("Choisir depuis la photothèque", systemImage: "photo")
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
            }
            .glassProminentButtonIfAvailable()
            .pressable()
            .padding(.top, 8)
        }
    }

    @MainActor
    private func handlePickedPhoto(_ item: PhotosPickerItem) async {
        isProcessingPhoto = true
        defer { isProcessingPhoto = false }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            scanError = "Impossible de charger la photo sélectionnée."
            return
        }

        if mode == .bankCard {
            if let result = await CardScanner.scanBankCard(from: image) {
                Haptics.success()
                onBankCardScanned?(result.number, result.expiry)
                dismiss()
            } else {
                Haptics.error()
                scanError = "Aucun numéro de carte bancaire valide détecté sur cette photo."
            }
        } else {
            if let result = await CardScanner.scanBarcode(from: image) {
                Haptics.success()
                onBarcodeScanned?(result.payload, result.format)
                dismiss()
            } else {
                Haptics.error()
                scanError = "Aucun code-barres ou QR détecté sur cette photo."
            }
        }
    }
}

/// Intégration UIKit de DataScannerViewController
private struct LiveScannerRepresentable: UIViewControllerRepresentable {
    let mode: ScannerMode
    let onBarcode: (String, BarcodeFormat) -> Void
    let onBankCard: (String, String?) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let recognizedTypes: Set<DataScannerViewController.RecognizedDataType>
        switch mode {
        case .barcode:
            recognizedTypes = [.barcode()]
        case .bankCard:
            recognizedTypes = [.text()]
        }

        let vc = DataScannerViewController(
            recognizedDataTypes: recognizedTypes,
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(mode: mode, onBarcode: onBarcode, onBankCard: onBankCard)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let mode: ScannerMode
        let onBarcode: (String, BarcodeFormat) -> Void
        let onBankCard: (String, String?) -> Void
        private var hasScanned = false

        init(mode: ScannerMode,
             onBarcode: @escaping (String, BarcodeFormat) -> Void,
             onBankCard: @escaping (String, String?) -> Void) {
            self.mode = mode
            self.onBarcode = onBarcode
            self.onBankCard = onBankCard
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !hasScanned else { return }

            for item in addedItems {
                switch (mode, item) {
                case (.barcode, .barcode(let barcode)):
                    guard let payload = barcode.payloadStringValue else { continue }
                    hasScanned = true
                    dataScanner.stopScanning()
                    let format = CardScanner.mapSymbology(barcode.observation.symbology)
                    onBarcode(payload, format)
                    return

                case (.bankCard, .text(let text)):
                    let lines = [text.transcript]
                    if let result = CardScanner.extractBankCardInfo(from: lines) {
                        hasScanned = true
                        dataScanner.stopScanning()
                        onBankCard(result.number, result.expiry)
                        return
                    }

                default:
                    break
                }
            }
        }
    }
}
