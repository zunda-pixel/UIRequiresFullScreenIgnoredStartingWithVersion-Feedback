import SwiftUI
import UIKit

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// Diagnostic view for how `UIRequiresFullScreen` behaves on iOS/iPadOS 27+.
///
/// Per WWDC26 "Modernize your UIKit app" (Session 278): starting in iOS 27, `UIRequiresFullScreen`
/// is *honored* in resizable environments and no longer opts the app out of resizing. Instead it
/// enables **discrete resizing** — as the user changes the scene size the system transitions the
/// scene to a new *screen configuration* matching that size (so a game always renders full quality),
/// rather than resizing continuously. `UIRequiresFullScreenIgnoredStartingWithVersion` opts back out
/// of that (continuous resizing) from the given version onward.
///
/// So the signal to observe is **continuous vs discrete** resizing, not aspect ratio:
/// - Dragging produces MANY finely-spaced window sizes -> CONTINUOUS (requirement ignored).
/// - Dragging snaps between a FEW distinct configurations -> DISCRETE (UIRequiresFullScreen honored).
///
/// This view records every distinct window size seen (`keyWindow.bounds`, the only reliable geometry
/// on iPadOS 26+) so you can drag-resize and inspect whether the sizes form a smooth ramp or a few
/// chunky configurations. Tap "Reset" before each experiment.
struct ContentView: View {
    /// Distinct window sizes observed, in order (consecutive duplicates collapsed).
    @State private var sizes: [CGSize] = []

    private var requiresFullScreen: String { infoValue("UIRequiresFullScreen") }
    private var ignoredStartingVersion: String { infoValue("UIRequiresFullScreenIgnoredStartingWithVersion") }
    private var configurationName: String { infoValue("ConfigurationName") }

    private var current: CGSize { sizes.last ?? .zero }

    /// Heuristic read on the samples so far (the size list below is the real evidence).
    private var verdict: String {
        switch sizes.count {
        case 0, 1: return "— (resize to test)"
        case 2...6: return "few steps → looks DISCRETE"
        default: return "many sizes → looks CONTINUOUS"
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Discrete-Resizing Test")
                        .font(.title2).bold()

                    VStack(alignment: .leading, spacing: 8) {
                        row("OS", value: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
                        row("Config", value: configurationName)
                        row("UIRequiresFullScreen", value: requiresFullScreen)
                        row("IgnoredStartingWithVersion", value: ignoredStartingVersion)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        row("Window", value: sizeString(current))
                        row("Distinct sizes", value: "\(sizes.count)")
                        row("Resizing looks", value: verdict)
                    }
                    .font(.system(.body, design: .monospaced))

                    Button("Reset") { sizes.removeAll(); record(proxy.size) }
                        .buttonStyle(.borderedProminent)

                    if !sizes.isEmpty {
                        Text("Observed sizes (newest first):")
                            .font(.footnote).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(sizes.enumerated().reversed()), id: \.offset) { _, size in
                                Text(sizeString(size))
                            }
                        }
                        .font(.system(.caption, design: .monospaced))
                    }

                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onAppear { record(currentWindowSize()) }
            .onChange(of: proxy.size) { _, _ in record(currentWindowSize()) }
        }
    }

    private var hint: String {
        """
        Drag a window corner slowly across a wide range, then read the list.
        • Many finely-spaced sizes -> CONTINUOUS resizing (requirement ignored)
        • A few distinct configurations (big jumps) -> DISCRETE resizing (UIRequiresFullScreen honored)
        Sizes come from keyWindow.bounds (UIScreen is unreliable on iPadOS 26+).
        """
    }

    /// Append the size if it differs from the most recent one (collapse consecutive duplicates).
    private func record(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        if let last = sizes.last, abs(last.width - size.width) < 1, abs(last.height - size.height) < 1 {
            return
        }
        sizes.append(size)
        if sizes.count > 60 { sizes.removeFirst(sizes.count - 60) }
    }

    private func currentWindowSize() -> CGSize {
        activeWindowScene()?.keyWindow?.bounds.size ?? .zero
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
