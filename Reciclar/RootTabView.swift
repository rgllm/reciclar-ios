import SwiftUI

struct RootTabView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            Tab("Mapa", systemImage: "map", value: AppTab.map) {
                MapTabView()
            }
            Tab("Reciclagem", systemImage: "arrow.3.trianglepath", value: AppTab.sorting) {
                SortingGuideTabView()
            }
            Tab("Estatísticas", systemImage: "chart.bar.xaxis", value: AppTab.stats) {
                StatsTabView()
            }
        }
        .tabBarMinimizeBehavior(.never)
    }
}

#Preview {
    PreviewRoot()
}

private struct PreviewRoot: View {
    @State private var model = AppModel(
        dependencies: .preview(),
        locationService: UserLocationService()
    )

    var body: some View {
        RootTabView()
            .environment(model)
            .environment(\.locale, Locale(identifier: "pt_PT"))
            .task { await model.start() }
    }
}
