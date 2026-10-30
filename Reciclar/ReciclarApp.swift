import SwiftUI

@main
struct ReciclarApp: App {
    @State private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let locationService = UserLocationService()
        _model = State(
            initialValue: AppModel(
                dependencies: .live(),
                locationService: locationService
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(model)
                .environment(\.locale, Locale(identifier: "pt_PT"))
                .task {
                    await model.start()
                    while !Task.isCancelled {
                        do { try await Task.sleep(for: .seconds(60)) } catch { return }
                        if scenePhase == .active { await model.refreshIfNeeded() }
                    }
                }
                .task(id: scenePhase) {
                    model.setSceneActive(scenePhase == .active)
                }
                .onChange(of: model.locationService.authorization) { _, _ in
                    if model.locationService.showsUserLocation {
                        Task { await model.centreOnUser() }
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task {
                            await model.returnedToForeground()
                        }
                    } else {
                        model.flushViewport()
                    }
                }
        }
    }
}
