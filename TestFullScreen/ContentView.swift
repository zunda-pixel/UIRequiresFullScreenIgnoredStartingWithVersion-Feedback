import SwiftUI
import UIKit

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// Diagnostic view for investigating how `UIRequiresFullScreen` and
/// `UIRequiresFullScreenIgnoredStartingWithVersion` behave on iPadOS 26+.
///
/// Findings from this project (Xcode 27 beta; iPadOS 26.5 / 27.0 simulators):
/// - `UIRequiresFullScreen`'s residual effect is an aspect-ratio / letterbox lock tied to the app's
///   declared interface orientations, and it is only honored on iPadOS 26.x. A restricted-orientation
///   app keeps its aspect ratio (letterboxed); an all-orientations app resizes freely. iPadOS 27
///   ignores the requirement entirely.
/// - `UIRequiresFullScreenIgnoredStartingWithVersion` had no observable effect in any tested case.
///
/// The observable signal is whether the window's aspect ratio stays constant while resizing.
/// We sample `keyWindow.bounds` (the only reliable geometry on iPadOS 26+; `UIScreen` is virtualized
/// per-window) and track the min/max observed aspect ratio:
/// - |max − min| ≈ 0 -> aspect ratio LOCKED
/// - clear spread    -> aspect ratio FREE
/// Tap "Reset min/max" to clear the samples before each experiment, then resize the window.
struct ContentView: View {
    @State private var windowSize: CGSize = .zero
    @State private var minAspect: Double = 0
    @State private var maxAspect: Double = 0
    @State private var hasSample: Bool = false

    private var requiresFullScreen: String { infoValue("UIRequiresFullScreen") }
    private var ignoredStartingVersion: String { infoValue("UIRequiresFullScreenIgnoredStartingWithVersion") }
    private var configurationName: String { infoValue("ConfigurationName") }

    private var currentAspect: Double {
        windowSize.height > 0 ? Double(windowSize.width / windowSize.height) : 0
    }

    /// Verdict based on the aspect-ratio spread observed so far.
    private var aspectVerdict: String {
        guard hasSample else { return "— (resize to test)" }
        let spread = maxAspect - minAspect
        return spread < 0.02
            ? "LOCKED (spread \(fmt(spread)))"
            : "FREE / varies (spread \(fmt(spread)))"
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Full-Screen / Aspect-Ratio Test")
                        .font(.title2).bold()

                    VStack(alignment: .leading, spacing: 8) {
                        row("OS", value: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
                        row("Config", value: configurationName)
                        row("UIRequiresFullScreen", value: requiresFullScreen)
                        row("IgnoredStartingWithVersion", value: ignoredStartingVersion)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        row("Window", value: sizeString(windowSize))
                        row("Aspect (w/h)", value: fmt(currentAspect))
                        row("Aspect min", value: hasSample ? fmt(minAspect) : "—")
                        row("Aspect max", value: hasSample ? fmt(maxAspect) : "—")
                        row("Aspect locked?", value: aspectVerdict)
                    }
                    .font(.system(.body, design: .monospaced))

                    Button("Reset min/max") { resetSamples() }
                        .buttonStyle(.borderedProminent)

                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // proxy.size changes on every resize; use it as a trigger to re-sample the real window.
            .onAppear { refresh() }
            .onChange(of: proxy.size) { _, _ in refresh() }
        }
    }

    private var hint: String {
        """
        Resize the window (window tiling controls, or drag a corner), then read the verdict.
        • Aspect stays LOCKED while resizing -> UIRequiresFullScreen honored (aspect-ratio lock)
        • Aspect varies (FREE) -> the requirement is ignored
        Judged from keyWindow.bounds (UIScreen is unreliable on iPadOS 26+).
        """
    }

    private func refresh() {
        windowSize = activeWindowScene()?.keyWindow?.bounds.size ?? .zero
        let aspect = currentAspect
        guard aspect > 0 else { return }
        if hasSample {
            minAspect = Swift.min(minAspect, aspect)
            maxAspect = Swift.max(maxAspect, aspect)
        } else {
            minAspect = aspect
            maxAspect = aspect
            hasSample = true
        }
    }

    private func resetSamples() {
        hasSample = false
        minAspect = 0
        maxAspect = 0
        refresh()
    }

    private func activeWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }

    private func infoValue(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key).map { String(describing: $0) } ?? "(not set)"
    }

    private func sizeString(_ size: CGSize) -> String {
        String(format: "%.0f × %.0f", size.width, size.height)
    }

    private func fmt(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    @ViewBuilder private func row(_ label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    ContentView()
}
