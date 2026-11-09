import OSLog
import SwiftUI
import UIKit

/// Measures the first frame boundary of the root UI, not map-tile or network readiness.
@MainActor
final class LaunchMeasurement {
    static let shared = LaunchMeasurement()
    private let startedAt = ProcessInfo.processInfo.systemUptime
    private let logger = Logger(subsystem: "com.rgllm.reciclar", category: "Launch")
    private var didRecord = false

    func recordFirstFrame() {
        guard !didRecord else { return }
        didRecord = true
        let milliseconds = (ProcessInfo.processInfo.systemUptime - startedAt) * 1_000
        logger.notice("App init to first frame: \(milliseconds, format: .fixed(precision: 1)) ms")
    }
}

/// The first callback precedes a frame. The second gives that frame a chance to
/// reach the display before releasing startup work. This is a frame-boundary
/// proxy, not a measurement of when physical pixels light up.
struct FirstFrameObserver: UIViewRepresentable {
    var onFirstFrame: @MainActor () -> Void

    func makeUIView(context: Context) -> FrameView {
        FrameView(onFirstFrame: onFirstFrame)
    }

    func updateUIView(_ uiView: FrameView, context: Context) {}

    final class FrameView: UIView {
        private var displayLink: CADisplayLink?
        private var sawFrame = false
        private var completed = false
        private let onFirstFrame: @MainActor () -> Void

        init(onFirstFrame: @escaping @MainActor () -> Void) {
            self.onFirstFrame = onFirstFrame
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            displayLink?.invalidate()
            displayLink = nil
            sawFrame = false
            guard window != nil, !completed else { return }
            let link = CADisplayLink(target: self, selector: #selector(frameBoundary))
            displayLink = link
            link.add(to: .main, forMode: .common)
        }

        @objc private func frameBoundary() {
            guard sawFrame else {
                sawFrame = true
                return
            }
            displayLink?.invalidate()
            displayLink = nil
            completed = true
            LaunchMeasurement.shared.recordFirstFrame()
            onFirstFrame()
        }
    }
}
