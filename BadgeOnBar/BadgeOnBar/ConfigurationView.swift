import SwiftUI
import AppKit
import Combine

struct ConfigurationView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(BadgeMonitor.self) private var monitor
    @State private var selectedAppID: String?
    @State private var trusted = PermissionsManager.isTrusted
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        if trusted {
            mainView
                .onReceive(timer) { _ in
                    if !PermissionsManager.isTrusted {
                        trusted = false
                        monitor.stop()
                    }
                }
        } else {
            AccessibilitySetupView()
                .onReceive(timer) { _ in
                    trusted = PermissionsManager.isTrusted
                }
        }
    }

    private var mainView: some View {
        NavigationSplitView {
            List(selection: $selectedAppID) {
                Section {
                    SettingsRow()
                        .tag("__settings__")
                } header: {
                    Text("Settings")
                }
                Section {
                    ForEach(monitoredApps) { app in
                        MonitoredAppRow(app: app)
                            .tag(app.id)
                    }
                } header: {
                    Text("Apps on Dock")
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            if selectedAppID == "__settings__" {
                SettingsDetailView()
            } else if let selectedID = selectedAppID,
                      let app = monitoredApps.first(where: { $0.id == selectedID }) {
                MonitoredAppDetailView(app: app)
            } else {
                WelcomeView()
            }
        }
        .onAppear {
            selectedAppID = "__settings__"
        }
    }

    private var monitoredApps: [MonitoredApp] {
        let dockIDs = Set(monitor.dockApps.map(\.bundleID))
        let runningIDs = Set(monitor.availableApps.map(\.bundleID))
        var apps: [MonitoredApp] = []

        for info in monitor.dockApps {
            apps.append(MonitoredApp(
                bundleID: info.bundleID,
                name: info.name,
                icon: info.icon,
                isRunning: runningIDs.contains(info.bundleID)
            ))
        }

        for bundleID in settings.monitoredBundleIDs where !dockIDs.contains(bundleID) {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
                  let bundle = Bundle(url: url) else { continue }
            let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? bundleID
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            apps.append(MonitoredApp(
                bundleID: bundleID,
                name: name,
                icon: icon,
                isRunning: runningIDs.contains(bundleID)
            ))
        }

        return apps
    }
}

private struct SettingsRow: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "gearshape")
                .resizable()
                .frame(width: 20, height: 20)
                .foregroundStyle(.secondary)
            Text("General")
                .lineLimit(1)
        }
    }
}

private struct SettingsDetailView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("General")
                .font(.title2)
                .fontWeight(.semibold)

            Toggle(isOn: Binding(
                get: { settings.startAtLogin },
                set: { settings.setStartAtLogin($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start at Login")
                    Text("Automatically launch Badge on Bar when you log in")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MonitoredApp: Identifiable {
    let bundleID: String
    let name: String
    let icon: NSImage?
    let isRunning: Bool
    var id: String { bundleID }
}

private struct MonitoredAppRow: View {
    let app: MonitoredApp
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let binding = Binding(
            get: { settings.isMonitored(app.bundleID) },
            set: { settings.setMonitored(app.bundleID, monitored: $0) }
        )
        HStack(spacing: 8) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .opacity(app.isRunning ? 1 : 0.35)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.secondary)
                    .opacity(app.isRunning ? 1 : 0.35)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .lineLimit(1)
                if !app.isRunning {
                    Text("Not running")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: binding)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}

private struct MonitoredAppDetailView: View {
    let app: MonitoredApp
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let binding = Binding(
            get: { settings.isMonitored(app.bundleID) },
            set: { settings.setMonitored(app.bundleID, monitored: $0) }
        )
        VStack(spacing: 24) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .opacity(app.isRunning ? 1 : 0.35)
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

            if !app.isRunning {
                Text("App is not currently running")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Toggle(isOn: binding) {
                Text(binding.wrappedValue ? "Showing in menu bar" : "Show in menu bar")
            }
            .toggleStyle(.switch)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AccessibilitySetupView: View {
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
        }
        .padding(40)
        .frame(width: 480, height: 420)
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
