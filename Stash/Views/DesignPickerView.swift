import SwiftUI

/// Sélecteur visuel de galerie de designs pour cartes.
/// Permet de choisir parmi les 17 visuels intégrés ou de revenir à une couleur unie / dégradé.
struct DesignPickerView: View {
    @Binding var selectedDesignID: String
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: CardDesignCategory = .all

    private var filteredDesigns: [CardDesign] {
        if selectedCategory == .all {
            return CardDesign.allDesigns
        }
        return CardDesign.allDesigns.filter { $0.category == selectedCategory }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Option « Aucun visuel (Couleur unie) »
                        Button {
                            Haptics.selection()
                            selectedDesignID = ""
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.stashRed)
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        Image(systemName: "paintpalette.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.white)
                                    }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Couleur personnalisée")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text("Utiliser le sélecteur de couleurs ou les teintes de la banque.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if selectedDesignID.isEmpty {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.stashRed)
                                        .font(.title3)
                                }
                            }
                            .padding(14)
                            .glassPanel(cornerRadius: 14)
                        }
                        .buttonStyle(.plain)

                        Text("Designs intégrés (\(filteredDesigns.count))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(filteredDesigns) { design in
                                designTile(design)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Galerie de designs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CardDesignCategory.allCases) { cat in
                    Button {
                        Haptics.selection()
                        withAnimation(Motion.snappy) {
                            selectedCategory = cat
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: cat.icon)
                                .font(.caption2)
                            Text(cat.label)
                                .font(.caption.weight(selectedCategory == cat ? .semibold : .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            selectedCategory == cat ? Color.stashRed : Color.secondary.opacity(0.15),
                            in: Capsule()
                        )
                        .foregroundStyle(selectedCategory == cat ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func designTile(_ design: CardDesign) -> some View {
        let isSelected = selectedDesignID == design.id

        return Button {
            Haptics.selection()
            selectedDesignID = design.id
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    design.image
                        .resizable()
                        .aspectRatio(1.585, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    isSelected ? Color.stashRed : Color.white.opacity(0.15),
                                    lineWidth: isSelected ? 2.5 : 1
                                )
                        }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.white, Color.stashRed)
                            .padding(6)
                    }
                }

                Text(design.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .pressable(scale: 0.95)
    }
}
