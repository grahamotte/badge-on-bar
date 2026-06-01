import SwiftUI
import Combine

struct ConfigurationView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(BadgeMonitor.self) private var monitor
    @State private var selectedAppID: String?
    @State private var trusted = PermissionsManager.isTrusted

    var body: some View {
        if trusted {
            mainView
                .onAppear { monitor.start() }
        } else {
            AccessibilitySetupView(trusted: $trusted)
        }
    }

    private var mainView: some View {
        NavigationSplitView {
            List(selection: $selectedAppID) {
                Section {
                    ForEach(monitor.availableApps) { app in
                        AppRow(app: app, isMonitored: settings.isMonitored(app.bundleID))
                            .tag(app.id)
                    }
                } header: {
                    Text("Running Apps")
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            if let selectedID = selectedAppID,
               let app = monitor.availableApps.first(where: { $0.id == selectedID }) {
                AppDetailView(app: app, isMonitored: settings.isMonitored(app.bundleID)) {
                    settings.toggle(app.bundleID)
                }
            } else {
                WelcomeView()
            }
        }
    }
}

private struct AccessibilitySetupView: View {
    @Binding var trusted: Bool
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "hand.raised.slash.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)

            Text("Accessibility Access Required")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                Text("Badge on Bar needs Accessibility access to read badge counts from the Dock.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Text("Your data never leaves your device. This permission is only used to display badge counts in the menu bar.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 40)

            VStack(spacing: 6) {
                Button("Open System Settings") {
                    PermissionsManager.openSettings()
                }
                .buttonStyle(.borderedProminent)

                Text("Then toggle Badge on Bar on and come back here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Waiting for permission...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(width: 480, height: 420)
        .onReceive(timer) { _ in
            trusted = PermissionsManager.isTrusted
        }
    }
}

private struct AppRow: View {
    let app: AppBadgeInfo
    let isMonitored: Bool

    var body: some View {
        HStack(spacing: 8) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.secondary)
            }
            Text(app.name)
                .lineLimit(1)
            Spacer()
            Image(systemName: isMonitored ? "eye.fill" : "eye.slash")
                .font(.caption)
                .foregroundStyle(isMonitored ? .blue : .secondary.opacity(0.4))
                .frame(width: 16)
        }
    }
}

private struct AppDetailView: View {
    let app: AppBadgeInfo
    let isMonitored: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 64, height: 64)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .frame(width: 64, height: 64)
                    .foregroundStyle(.secondary)
            }

            Text(app.name)
                .font(.title2)

            Text(app.bundleID)
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle(isOn: Binding(
                get: { isMonitored },
                set: { _ in onToggle() }
            )) {
                Text(isMonitored ? "Showing in menu bar" : "Show in menu bar")
            }
            .toggleStyle(.switch)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "app.badge")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Badge on Bar")
                .font(.title)

            Text("Select an app from the sidebar to toggle menu bar monitoring. When enabled, the app's icon and badge count will appear in your menu bar.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
