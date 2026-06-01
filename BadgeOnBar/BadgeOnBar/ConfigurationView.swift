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
            AccessibilitySetupView(trusted: $trusted)
                .onReceive(timer) { _ in
                    trusted = PermissionsManager.isTrusted
                }
        }
    }

    private var mainView: some View {
        NavigationSplitView {
            List(selection: $selectedAppID) {
                Section {
                    ForEach(monitoredApps) { app in
                        MonitoredAppRow(app: app) {
                            settings.toggle(app.bundleID)
                        }
                        .tag(app.id)
                    }
                } header: {
                    Text("Apps on Dock")
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            if let selectedID = selectedAppID,
               let app = monitoredApps.first(where: { $0.id == selectedID }) {
                MonitoredAppDetailView(app: app) {
                    settings.toggle(app.bundleID)
                }
            } else {
                WelcomeView()
            }
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
                isRunning: runningIDs.contains(info.bundleID),
                isEnabled: settings.isMonitored(info.bundleID)
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
                isRunning: runningIDs.contains(bundleID),
                isEnabled: true
            ))
        }

        return apps
    }
}

private struct MonitoredApp: Identifiable {
    let bundleID: String
    let name: String
    let icon: NSImage?
    let isRunning: Bool
    let isEnabled: Bool
    var id: String { bundleID }
}

private struct MonitoredAppRow: View {
    let app: MonitoredApp
    let onToggle: () -> Void

    var body: some View {
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
            Toggle("", isOn: Binding(
                get: { app.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
    }
}

private struct MonitoredAppDetailView: View {
    let app: MonitoredApp
    let onToggle: () -> Void

    var body: some View {
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

            Toggle(isOn: Binding(
                get: { app.isEnabled },
                set: { _ in onToggle() }
            )) {
                Text(app.isEnabled ? "Showing in menu bar" : "Show in menu bar")
            }
            .toggleStyle(.switch)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        }
        .padding(40)
        .frame(width: 480, height: 420)
        .onReceive(timer) { _ in
            trusted = PermissionsManager.isTrusted
        }
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
