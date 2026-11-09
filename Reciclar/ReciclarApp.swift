import SwiftUI

@main
struct ReciclarApp: App {
    @State private var model: AppModel
    @State private var firstFramePresented = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        _ = LaunchMeasurement.shared
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
                .background {
                    FirstFrameObserver { firstFramePresented = true }
                }
                .task(id: firstFramePresented) {
                    guard firstFramePresented else { return }
                    await model.start()
                }
                .task(id: scenePhase) {
                    model.setSceneActive(scenePhase == .active)
                    guard scenePhase == .active else { return }
                    while !Task.isCancelled {
                        do { try await Task.sleep(for: .seconds(60)) } catch { return }
                        guard !Task.isCancelled else { return }
                        await model.refreshIfNeeded()
                    }
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
