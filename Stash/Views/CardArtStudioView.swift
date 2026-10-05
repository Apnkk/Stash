import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Le Studio CardArt : permet de personnaliser entièrement le visuel de la carte bancaire.
/// Intègre :
/// 1. La galerie officielle de designs intégrés (29+ designs avec filtres par catégorie et recommandation automatique).
/// 2. L'importation directe de fichiers images (permettant d'importer n'importe quel fichier de la collection CardArt locale/iCloud).
/// 3. L'importation depuis la photothèque iOS via PhotosPicker.
/// 4. Le nuancier de finitions de luxe et les réglages de calque (activation/désactivation de la puce EMV).
struct CardArtStudioView: View {
    @Binding var selectedDesignID: String
    @Binding var customArtImage: UIImage?
    @Binding var colorHex: String
    @Binding var showChip: Bool

    var recommendedNetwork: CardNetwork = .unknown
    var detectedBankName: String = ""

    @State private var selectedTab: StudioTab = .gallery
    @State private var selectedCategory: CardDesignCategory = .all
    @State private var showingFileImporter: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var fileImportError: String? = nil

    private enum StudioTab: String, CaseIterable, Identifiable {
        case gallery
        case filesAndPhotos
        case palette

        var id: String { rawValue }

        var label: String {
            switch self {
            case .gallery:        return "Galerie Officielle"
            case .filesAndPhotos: return "Importer un Fichier"
            case .palette:        return "Teintes & Puce"
            }
        }

        var icon: String {
            switch self {
            case .gallery:        return "sparkles"
            case .filesAndPhotos: return "folder.badge.plus"
            case .palette:        return "paintpalette.fill"
            }
        }
    }

    /// Filtre les designs selon la catégorie choisie, en mettant en avant les recommandations.
    private var displayedDesigns: [CardDesign] {
        if selectedCategory == .all {
            let recommended = CardDesign.recommended(network: recommendedNetwork, bankName: detectedBankName)
            var list = recommended
            for d in CardDesign.allDesigns where !list.contains(d) {
                list.append(d)
            }
            return list
        }
        return CardDesign.allDesigns.filter { $0.category == selectedCategory }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Sélecteur d'onglets du Studio
            studioTabsPicker

            switch selectedTab {
            case .gallery:
                officialGallerySection
            case .filesAndPhotos:
                fileAndPhotoImportSection
            case .palette:
                paletteAndTogglesSection
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.png, .jpeg, .image],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            handlePhotoSelection(newItem)
        }
    }

    // MARK: - Sélecteur d'onglets

    private var studioTabsPicker: some View {
        HStack(spacing: 6) {
            ForEach(StudioTab.allCases) { tab in
                Button {
                    Haptics.selection()
                    withAnimation(Motion.snappy) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(tab.label)
                            .font(.caption.weight(selectedTab == tab ? .bold : .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        selectedTab == tab ? Color.stashRed : Color.secondary.opacity(0.12),
                        in: Capsule()
                    )
                    .foregroundStyle(selectedTab == tab ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Section 1 : Galerie Officielle

    private var officialGallerySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Filtres thématiques
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(CardDesignCategory.allCases) { cat in
                        Button {
                            Haptics.selection()
                            withAnimation(Motion.snappy) {
                                selectedCategory = cat
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 10))
                                Text(cat.label)
                                    .font(.caption2.weight(selectedCategory == cat ? .bold : .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                selectedCategory == cat ? Color.stashRed.opacity(0.2) : Color.secondary.opacity(0.08),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        selectedCategory == cat ? Color.stashRed : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                            .foregroundStyle(selectedCategory == cat ? Color.stashRed : Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }

            // Grille visuelle des visuels officiels
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                ForEach(displayedDesigns) { design in
                    designTile(design)
                }
            }
        }
    }

    private func designTile(_ design: CardDesign) -> some View {
        let isSelected = selectedDesignID == design.id && customArtImage == nil

        return Button {
            Haptics.selection()
            withAnimation(Motion.snappy) {
                selectedDesignID = design.id
                customArtImage = nil
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    design.image
                        .resizable()
                        .aspectRatio(1.585, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(
                                    isSelected ? Color.stashRed : Color.white.opacity(0.18),
                                    lineWidth: isSelected ? 2.5 : 1
                                )
                        }
                        .shadow(color: Color.black.opacity(isSelected ? 0.35 : 0.15), radius: 6, y: 3)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.white, Color.stashRed)
                            .padding(6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Text(design.name)
                    .font(.caption2.weight(isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.stashRed : Color.primary)
                    .lineLimit(1)
            }
            .padding(2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section 2 : Import Fichiers & Photos

    private var fileAndPhotoImportSection: some View {
        VStack(spacing: 14) {
            // Carte explicative
            HStack(spacing: 12) {
                Image(systemName: "photo.stack.fill")
                    .font(.title2)
                    .foregroundStyle(Color.stashRed)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Collection CardArt (5 266 designs)")
                        .font(.subheadline.weight(.semibold))
                    Text("Importe n'importe quel fichier présent dans ton dossier CardArt ou ta photothèque.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .glassPanel(cornerRadius: 14)

            // Bouton 1 : Fichiers iOS (.fileImporter)
            Button {
                Haptics.light()
                showingFileImporter = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "folder.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.orange)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Parcourir dans Fichiers")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Dossier CardArt, iCloud Drive ou stockage local de l'iPhone.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .glassPanel(cornerRadius: 14)
            }
            .buttonStyle(.plain)

            // Bouton 2 : Photothèque (PhotosPicker)
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.blue)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Choisir dans Photos")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Pellicule, captures d'écran ou albums photo.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .glassPanel(cornerRadius: 14)
            }
            .buttonStyle(.plain)

            if customArtImage != nil {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Image personnalisée appliquée avec succès.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Supprimer") {
                        Haptics.light()
                        withAnimation(Motion.snappy) {
                            customArtImage = nil
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                }
                .padding(.horizontal, 4)
            }

            if let error = fileImportError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Section 3 : Nuancier & Réglages

    private var paletteAndTogglesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Nuancier de finitions de luxe
            VStack(alignment: .leading, spacing: 8) {
                Text("Teinte de fond personnalisée :")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 42), spacing: 10)], spacing: 10) {
                    ForEach(Palette.colors, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 36, height: 36)
                            .overlay {
                                if hex == colorHex && selectedDesignID.isEmpty && customArtImage == nil {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Color.white)
                                }
                            }
                            .scaleEffect(hex == colorHex && selectedDesignID.isEmpty && customArtImage == nil ? 1.1 : 1.0)
                            .onTapGesture {
                                Haptics.selection()
                                withAnimation(Motion.snappy) {
                                    colorHex = hex
                                    selectedDesignID = ""
                                    customArtImage = nil
                                }
                            }
                    }
                }
                .padding(.vertical, 4)
            }

            Divider()

            // Interrupteur de puce physique EMV
            Toggle(isOn: $showChip) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Afficher la puce dorée EMV")
                        .font(.subheadline.weight(.semibold))
                    Text("Désactive cette option si le visuel importé contient déjà une puce imprimée.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(Color.stashRed)
            .padding(14)
            .glassPanel(cornerRadius: 14)
        }
    }

    // MARK: - Gestion des imports de fichiers

    private func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            guard let selectedURL = try result.get().first else { return }
            guard selectedURL.startAccessingSecurityScopedResource() else {
                fileImportError = "Accès refusé au fichier sélectionné."
                return
            }
            defer { selectedURL.stopAccessingSecurityScopedResource() }

            let data = try Data(contentsOf: selectedURL)
            guard let image = UIImage(data: data) else {
                fileImportError = "Format d'image non reconnu."
                return
            }

            self.customArtImage = image
            self.selectedDesignID = ""
            self.fileImportError = nil
            Haptics.success()
        } catch {
            fileImportError = "Impossible de charger l'image : \(error.localizedDescription)"
        }
    }

    private func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    self.customArtImage = image
                    self.selectedDesignID = ""
                    self.fileImportError = nil
                    Haptics.success()
                }
            }
        }
    }
}
