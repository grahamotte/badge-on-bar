import AppKit
import Observation

struct AppBadgeInfo: Identifiable, Equatable {
    let bundleID: String
    let name: String
    let icon: NSImage?

    var id: String { bundleID }

    static func == (lhs: AppBadgeInfo, rhs: AppBadgeInfo) -> Bool {
        lhs.bundleID == rhs.bundleID
    }
}

@MainActor
@Observable
final class BadgeMonitor {
    var badges: [String: Int] = [:]
    var availableApps: [AppBadgeInfo] = []

    var onUpdate: (() -> Void)?

    private var isRunning = false
    private var timer: Timer?
    private var observer: AXObserver?

    func start() {
        guard !isRunning, PermissionsManager.isTrusted else { return }
        isRunning = true

        refreshRunningApps()
        pollBadges()

        timer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(timerFired),
            userInfo: nil,
            repeats: true
        )

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            self,
            selector: #selector(appLaunched),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(appTerminated),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )

        setupAXObserver()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dockChanged),
            name: .dockElementsChanged,
            object: nil
        )
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
            self.observer = nil
        }
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Selector callbacks (non-isolated to avoid capturing self in Sendable closures)

    @objc nonisolated private func timerFired() {
        MainActor.assumeIsolated {
            pollBadges()
        }
    }

    @objc nonisolated private func appLaunched() {
        MainActor.assumeIsolated {
            refreshRunningApps()
        }
    }

    @objc nonisolated private func appTerminated() {
        MainActor.assumeIsolated {
            refreshRunningApps()
        }
    }

    @objc nonisolated private func dockChanged() {
        MainActor.assumeIsolated {
            pollBadges()
        }
    }

    // MARK: - Monitoring

    private func refreshRunningApps() {
        let apps = NSWorkspace.shared.runningApplications.filter { app in
            app.activationPolicy == .regular && app.bundleIdentifier != nil
        }
        availableApps = apps.compactMap { app in
            guard let bundleID = app.bundleIdentifier else { return nil }
            let icon: NSImage? = {
                if let url = app.bundleURL {
                    return NSWorkspace.shared.icon(forFile: url.path)
                }
                return app.icon
            }()
            return AppBadgeInfo(
                bundleID: bundleID,
                name: app.localizedName ?? bundleID,
                icon: icon
            )
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        onUpdate?()
    }

    private func pollBadges() {
        refreshRunningApps()

        let pid = getDockPID()
        guard pid != 0 else { return }

        let dockApp = AXUIElementCreateApplication(pid)
        guard let children = axAttribute(dockApp, kAXChildrenAttribute as CFString) as? [AXUIElement] else { return }

        var counts: [String: Int] = [:]
        walkDockElements(children, into: &counts)
        badges = counts
        onUpdate?()
    }

    private func walkDockElements(_ elements: [AXUIElement], into counts: inout [String: Int]) {
        for element in elements {
            let title = axAttribute(element, kAXTitleAttribute as CFString) as? String
            let label = axAttribute(element, "AXStatusLabel" as CFString) as? String

            if let title, let label, !label.isEmpty,
               let app = availableApps.first(where: { $0.name == title }),
               let count = Int(label) {
                counts[app.bundleID] = count
            }

            if let children = axAttribute(element, kAXChildrenAttribute as CFString) as? [AXUIElement] {
                walkDockElements(children, into: &counts)
            }
        }
    }

    private func getDockPID() -> pid_t {
        NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == "com.apple.dock" })?
            .processIdentifier ?? 0
    }

    private func axAttribute(_ element: AXUIElement, _ attribute: CFString) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else { return nil }
        return value
    }

    private func setupAXObserver() {
        let pid = getDockPID()
        guard pid != 0 else { return }

        var obs: AXObserver?
        let result = AXObserverCreate(pid, { _, _, _, _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .dockElementsChanged, object: nil)
            }
        }, &obs)

        guard result == .success, let obs else { return }

        let dockApp = AXUIElementCreateApplication(pid)
        AXObserverAddNotification(obs, dockApp, kAXCreatedNotification as CFString, nil)
        AXObserverAddNotification(obs, dockApp, kAXUIElementDestroyedNotification as CFString, nil)

        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(obs), .defaultMode)
        self.observer = obs
    }
}

extension Notification.Name {
    static let dockElementsChanged = Notification.Name("dockElementsChanged")
}
