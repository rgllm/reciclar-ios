import ReciclarCore
import SwiftUI

struct MapFilterSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var onShowList: () -> Void
    var onShowFavourites: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Com várias categorias escolhidas, só aparecem locais que aceitam todas. ")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Resíduos") {
                    ForEach(model.filterChips) { chip in
                        let selected = model.filter.requiredTokens.contains(chip.token)
                        Button {
                            model.toggleToken(chip.token)
                        } label: {
                            HStack {
                                Label(chip.name, systemImage: WasteCategoryPresentation.symbol(for: chip))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selected {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(MapPalette.pin)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .accessibilityAddTraits(selected ? [.isSelected] : [])
                    }
                }

                Section("Espaço") {
                    Toggle("Com espaço", isOn: Binding(
                        get: { model.filter.requiresSpaceAvailable },
                        set: { _ in model.toggleSpaceAvailable() }
                    ))
                    Text("Leitura abaixo de 90 % e com no máximo 24 horas. Não garante que o item caiba, e não usa relatos da comunidade.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Label(
                            model.status == .refreshing || model.status == .loading
                                ? "A atualizar…"
                                : "Atualizar dados",
                            systemImage: "arrow.clockwise"
                        )
                    }
                    .disabled(model.status == .refreshing || model.status == .loading)
                    .accessibilityHint("Atualiza os ecopontos e as observações guardados na app.")
                    if let synced = model.snapshot.lastSuccessfulSync {
                        Text("Última atualização na app \(PortugueseRelativeTime.phrase(from: synced, now: model.now)). Isto não é a data das leituras.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let note = model.snapshot.coverageNote, !model.snapshot.isFixtureData {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Lista de ecopontos visíveis", systemImage: "list.bullet") {
                        dismiss()
                        onShowList()
                    }
                    Button("Favoritos", systemImage: "star") {
                        dismiss()
                        onShowFavourites()
                    }
                }

                if model.filter.isActive {
                    Section {
                        Button("Limpar filtros", systemImage: "xmark.circle") {
                            model.resetFilters()
                        }
                    }
                }
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
