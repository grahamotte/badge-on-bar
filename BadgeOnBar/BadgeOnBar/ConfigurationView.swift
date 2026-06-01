import SwiftUI

struct ConfigurationView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(BadgeMonitor.self) private var monitor
    @State private var selectedAppID: String?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedAppID) {
                if !PermissionsManager.isTrusted {
                    Label("Accessibility Required", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }

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
            .safeAreaInset(edge: .bottom) {
                if !PermissionsManager.isTrusted {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Accessibility access is needed to read Dock badge counts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Open System Settings") {
                            PermissionsManager.openSettings()
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
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
