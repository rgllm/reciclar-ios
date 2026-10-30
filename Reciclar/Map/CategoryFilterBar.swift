import ReciclarCore
import SwiftUI

struct CategoryFilterBar: View {
    @Environment(AppModel.self) private var model
    var onOpenFilters: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                MapSquareButton(
                    systemImage: "slider.horizontal.3",
                    accessibilityLabel: "Mais filtros",
                    accessibilityHint: "Abre a lista, os favoritos e a explicação dos filtros. Com várias categorias, o local tem de aceitar todas."
                ) {
                    onOpenFilters()
                }

                ForEach(model.filterChips) { chip in
                    let selected = model.filter.requiredTokens.contains(chip.token)
                    MapFilterChip(
                        title: chip.name,
                        systemImage: WasteCategoryPresentation.symbol(for: chip),
                        isSelected: selected
                    ) {
                        model.toggleToken(chip.token)
                    }
                    .accessibilityHint("Mostra só locais que aceitam esta categoria. Com várias escolhidas, o local tem de aceitar todas.")
                }

                MapFilterChip(
                    title: "Com espaço",
                    systemImage: "gauge.with.needle",
                    isSelected: model.filter.requiresSpaceAvailable
                ) {
                    model.toggleSpaceAvailable()
                }
                .accessibilityHint("Mostra locais com leitura abaixo de 90 por cento e com no máximo 24 horas. Não garante que o item caiba.")

                if model.filter.isActive {
                    MapFilterChip(title: "Limpar", systemImage: "xmark", isSelected: false) {
                        model.resetFilters()
                    }
                    .accessibilityHint("Remove todas as categorias e o filtro de espaço.")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .scrollClipDisabled()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filtros de resíduos")
    }
}
