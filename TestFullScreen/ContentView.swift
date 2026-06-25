import SwiftUI
import UIKit
import Playgrounds

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// Diagnostic view to observe, on device/simulator, whether the combination of
/// `UIRequiresFullScreen` and `UIRequiresFullScreenIgnoredStartingWithVersion` behaves correctly.
///
/// Important: under iPadOS 26+ windowing, `UIScreen` (both `bounds` and `nativeBounds`) is
/// virtualized as a per-window screen and does NOT report the physical display size. The only
/// reliable in-app signal is `keyWindow.bounds` (the "Window" row); the screenshot is ground truth.
/// - Window smaller than the full display  -> `UIRequiresFullScreen` is being ignored (resizable).
/// - Window always fills the display        -> it is being honored (forced full screen).
/// `scene.isFullScreen` is shown as the system's raw flag for reference (it can be unreliable in beta).
struct ContentView: View {
    @State private var windowSize: CGSize = .zero
    @State private var sceneIsFullScreen: Bool = false

    private var requiresFullScreen: String { infoValue("UIRequiresFullScreen") }
    private var ignoredStartingVersion: String { infoValue("UIRequiresFullScreenIgnoredStartingWithVersion") }
    private var configurationName: String { infoValue("ConfigurationName") }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Full-Screen Requirement Test")
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
                        row("scene.isFullScreen", value: sceneIsFullScreen ? "true" : "false")
                    }
                    .font(.system(.body, design: .monospaced))

                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // proxy.size is used only as a resize trigger; real values are re-read from UIKit.
            .onAppear { refresh() }
            .onChange(of: proxy.size) { _, _ in refresh() }
        }
    }

    private var hint: String {
        """
        Judge by the Window size (UIScreen is unreliable on iPadOS 26+).
        • Window smaller than the display -> ignored (resizable)
        • Window always fills the display -> forced full screen (UIRequiresFullScreen honored)
        """
    }

    private func refresh() {
        let scene = activeWindowScene()
        windowSize = scene?.keyWindow?.bounds.size ?? .zero
        sceneIsFullScreen = scene?.isFullScreen ?? false
    }

    private func activeWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }

    private func infoValue(_ key: String) -> String {
        if let value = Bundle.main.object(forInfoDictionaryKey: key) {
            return String(describing: value)
        }
        return "(not set)"
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

#Playground {
    _ = 1 + 2
}
