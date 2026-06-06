import SwiftUI
import AppKit
import Combine

private let menuBarSymbolOptions = [
    "paperplane.fill", "number.square.fill", "checkmark.square.fill", "envelope.fill", "message.fill",
    "bubble.left.and.bubble.right.fill", "line.3.horizontal.circle.fill", "bell.fill", "calendar.circle.fill", "checkmark.circle.fill",
    "list.bullet.circle.fill", "tray.fill", "doc.text.fill", "folder.fill", "paperclip.circle.fill",
    "person.fill", "person.2.fill", "phone.fill", "video.fill", "mic.fill",
    "camera.fill", "cart.fill", "creditcard.fill", "chart.bar.fill",
    "clock.fill", "timer.circle.fill", "flag.fill", "bookmark.fill", "star.fill",
    "heart.fill", "bolt.fill", "flame.fill", "cloud.fill", "lock.fill",
    "key.fill", "shield.fill", "wifi.circle.fill", "terminal.fill", "gearshape.fill",
    "magnifyingglass.circle.fill", "circle.grid.hex.fill", "line.3.horizontal.decrease.circle.fill",
    "grid.circle.fill", "hand.thumbsup.fill", "slash.circle.fill", "list.bullet", "smiley.fill"
]

struct ConfigurationView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(BadgeMonitor.self) private var monitor
    @State private var selectedAppID: String?
    @State private var trusted = PermissionsManager.isTrusted
    @State private var otherAppsExpanded = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        if trusted {
            mainView
                .onAppear {
                    settings.refreshStartAtLoginStatus()
                    updateTrust(PermissionsManager.isTrusted)
                }
                .onReceive(timer) { _ in
                    updateTrust(PermissionsManager.isTrusted)
                }
        } else {
            AccessibilitySetupView()
                .onAppear {
                    updateTrust(PermissionsManager.isTrusted)
                }
                .onReceive(timer) { _ in
                    updateTrust(PermissionsManager.isTrusted)
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
                    ForEach(dockApps) { app in
                        MonitoredAppRow(app: app)
                            .tag(app.id)
                    }
                } header: {
                    Text("Apps on Dock")
                }
                Section(isExpanded: $otherAppsExpanded) {
                    ForEach(otherApps) { app in
                        MonitoredAppRow(app: app)
                            .tag(app.id)
                    }
                } header: {
                    Text("Other Apps")
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 280)
        } detail: {
            if selectedAppID == "__settings__" {
                SettingsDetailView()
            } else if let selectedID = selectedAppID,
                      let app = allApps.first(where: { $0.id == selectedID }) {
                MonitoredAppDetailView(app: app)
            } else {
                WelcomeView()
            }
        }
        .onAppear {
            selectedAppID = "__settings__"
        }
        .toolbar(removing: .sidebarToggle)
        .frame(minWidth: 760, idealWidth: 820, minHeight: 500, idealHeight: 560)
    }

    private var dockApps: [MonitoredApp] {
        monitor.dockApps
            .map { MonitoredApp(bundleID: $0.bundleID, name: $0.name, icon: $0.icon, isOnDock: true) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var otherApps: [MonitoredApp] {
        let dockIDs = Set(monitor.dockApps.map(\.bundleID))
        var appsByID = Dictionary(uniqueKeysWithValues: monitor.installedApps
            .filter { !dockIDs.contains($0.bundleID) }
            .map { ($0.bundleID, MonitoredApp(bundleID: $0.bundleID, name: $0.name, icon: $0.icon, isOnDock: false)) })

        for bundleID in settings.monitoredBundleIDs where !dockIDs.contains(bundleID) {
            guard let info = AppBadgeInfo.fromBundleID(bundleID) else { continue }
            appsByID[bundleID] = MonitoredApp(bundleID: info.bundleID, name: info.name, icon: info.icon, isOnDock: false)
        }

        return appsByID.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var allApps: [MonitoredApp] {
        dockApps + otherApps
    }

    private func updateTrust(_ isTrusted: Bool) {
        guard trusted != isTrusted else { return }
        trusted = isTrusted
        isTrusted ? monitor.start() : monitor.stop()
    }
}

private struct SettingsRow: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
            Text("General")
                .lineLimit(1)
            Spacer()
            Text("\(settings.monitoredBundleIDs.count)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
        }
    }
}

private struct SettingsDetailView: View {
    @Environment(AppSettings.self) private var settings
    private let demoCounts = [-1, 0, 1, 3, 21, 99, 999]

    var body: some View {
        DetailPage {
            HeaderView(
                icon: "gearshape.fill",
                title: "General",
                subtitle: "\(settings.monitoredBundleIDs.count) monitored app\(settings.monitoredBundleIDs.count == 1 ? "" : "s")"
            )

            SettingToggle(
                title: "Start at Login",
                subtitle: "Launch quietly when you sign in.",
                isOn: Binding(
                    get: { settings.startAtLogin },
                    set: { settings.setStartAtLogin($0) }
                )
            )

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                Text("Default Display")
                    .fontWeight(.medium)

                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Show as Dot")
                            .fontWeight(.medium)
                        Text("Replace badge counts with a small dot for new apps.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { settings.dotBadgeDefault },
                        set: { settings.setDotBadgeDefault($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    Button("Change All") {
                        settings.setAllDotBadgesToDefault()
                    }
                    .disabled(settings.allDotBadgesMatchDefault)
                    .controlSize(.small)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Debug")
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    ForEach(demoCounts, id: \.self) { count in
                        Button("\(count)") {
                            settings.showBadgeDemo(count)
                        }
                        .controlSize(.small)
                    }
                }
            }
        }
    }
}

private struct MonitoredApp: Identifiable {
    let bundleID: String
    let name: String
    let icon: NSImage?
    let isOnDock: Bool
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
            AppIconView(icon: app.icon, size: 24)
            Text(app.name)
                .lineLimit(1)
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
        let symbolBinding = Binding<String?>(
            get: { settings.symbolOverride(for: app.bundleID) },
            set: { settings.setSymbolOverride(app.bundleID, symbolName: $0) }
        )

        DetailPage {
            HStack(spacing: 18) {
                AppIconView(icon: app.icon, size: 64)
                VStack(alignment: .leading, spacing: 6) {
                    Text(app.name)
                        .font(.title2.weight(.semibold))
                    Text(app.bundleID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                StatusPill(text: binding.wrappedValue ? "Monitoring" : "Not Monitored", systemImage: binding.wrappedValue ? "checkmark.circle.fill" : "pause.circle")
                Spacer()
            }

            SettingToggle(
                title: binding.wrappedValue ? "Shown in Menu Bar" : "Show in Menu Bar",
                subtitle: app.isOnDock ? "Display this app's badge count as its own menu bar item." : "Saved, but the app is not currently on the Dock.",
                isOn: binding
            )

            Divider()

            SettingToggle(
                title: "Show as Dot",
                subtitle: "Replace the badge count with a small dot.",
                isOn: Binding(
                    get: { settings.isDotBadge(app.bundleID) },
                    set: { settings.setDotBadge(app.bundleID, enabled: $0) }
                )
            )

            Divider()

            MenuBarIconGrid(appIcon: app.icon, selection: symbolBinding)
        }
    }
}

private struct MenuBarIconGrid: View {
    let appIcon: NSImage?
    let selection: Binding<String?>
    private let columns = [GridItem(.adaptive(minimum: 32, maximum: 32), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Menu Bar Icon")
                .fontWeight(.medium)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                IconChoiceButton(isSelected: selection.wrappedValue == nil, accessibilityLabel: "App Icon") {
                    AppIconView(icon: appIcon, size: 18)
                } action: {
                    selection.wrappedValue = nil
                }

                ForEach(menuBarSymbolOptions, id: \.self) { symbol in
                    IconChoiceButton(isSelected: selection.wrappedValue == symbol, accessibilityLabel: symbol) {
                        Image(systemName: symbol)
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 18, height: 18)
                    } action: {
                        selection.wrappedValue = symbol
                    }
                }
            }
            .padding(6)
        }
    }
}

private struct IconChoiceButton<Content: View>: View {
    let isSelected: Bool
    let accessibilityLabel: String
    @ViewBuilder var content: Content
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            content
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(width: 32, height: 32)
                .background(isSelected ? Color.accentColor.opacity(0.22) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.18), lineWidth: isSelected ? 1.5 : 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct AccessibilitySetupView: View {
    var body: some View {
        VStack(spacing: 26) {
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
        .padding(44)
        .frame(width: 520, height: 440)
        .background(.regularMaterial)
    }
}

private struct WelcomeView: View {
    var body: some View {
        DetailPage {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "menubar.rectangle")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("Choose an App")
                    .font(.title2.weight(.semibold))

                Text("Select an app in the sidebar to control whether its badge appears in the menu bar.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 360)
            }
            .frame(maxWidth: .infinity)
            Spacer()
        }
    }
}

private struct DetailPage<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            content
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.background)
    }
}

private struct HeaderView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AppIconView: View {
    let icon: NSImage?
    let size: CGFloat

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
                    .padding(size * 0.18)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct SettingToggle: View {
    let title: String
    let subtitle: String
    let isOn: Binding<Bool>

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}

private struct StatusPill: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.quaternary, in: Capsule())
    }
}
