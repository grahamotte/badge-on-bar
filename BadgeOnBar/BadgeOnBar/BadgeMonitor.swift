import AppKit
import Observation
import OSLog

private let monLog = Logger(subsystem: "com.grahamotte.badgeonbar", category: "BadgeMonitor")

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
    var dockApps: [AppBadgeInfo] = []

    var onUpdate: (() -> Void)?

    private var isRunning = false
    private var timer: Timer?
    private var observer: AXObserver?
    private var dockAppElements: [String: AXUIElement] = [:]
    private var installedAppRegistry: [String: (bundleID: String, name: String)] = [:]

    func start() {
        guard !isRunning, PermissionsManager.isTrusted else {
            if !PermissionsManager.isTrusted { monLog.error("start: access not trusted") }
            return
        }
        isRunning = true

        buildInstalledAppRegistry()
        refreshRunningApps()
        reloadDockElements()
        readBadges()
        notifyUpdate()

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

    @objc nonisolated private func timerFired() {
        MainActor.assumeIsolated {
            if dockAppElements.isEmpty {
                refreshRunningApps()
                reloadDockElements()
            }
            readBadges()
            notifyUpdate()
        }
    }

    @objc nonisolated private func appLaunched() {
        MainActor.assumeIsolated {
            refreshRunningApps()
            reloadDockElements()
            readBadges()
            notifyUpdate()
        }
    }

    @objc nonisolated private func appTerminated() {
        MainActor.assumeIsolated {
            refreshRunningApps()
            reloadDockElements()
            readBadges()
            notifyUpdate()
        }
    }

    @objc nonisolated private func dockChanged() {
        MainActor.assumeIsolated {
            reloadDockElements()
            readBadges()
            notifyUpdate()
        }
    }

    private func notifyUpdate() {
        onUpdate?()
    }

    private func refreshRunningApps() {
        let apps = NSWorkspace.shared.runningApplications.filter { app in
            app.activationPolicy == .regular && app.bundleIdentifier != nil
        }
        availableApps = apps.compactMap { app in
            guard let bundleID = app.bundleIdentifier else { return nil }
            return AppBadgeInfo(
                bundleID: bundleID,
                name: app.localizedName ?? bundleID,
                icon: app.icon
            )
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func buildInstalledAppRegistry() {
        var registry: [String: (bundleID: String, name: String)] = [:]
        let dirs = ["/Applications", "/System/Applications",
                    NSString(string: "~/Applications").expandingTildeInPath]
        let fm = FileManager.default
        for dir in dirs {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in contents where item.hasSuffix(".app") {
                let path = "\(dir)/\(item)"
                guard let bundle = Bundle(path: path),
                      let bundleID = bundle.bundleIdentifier else { continue }
                let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? item.replacingOccurrences(of: ".app", with: "")
                registry[name] = (bundleID, name)
            }
        }
        installedAppRegistry = registry
    }

    private func reloadDockElements() {
        let pid = getDockPID()
        guard pid != 0 else {
            monLog.error("reloadDockElements: no Dock PID")
            return
        }

        let dockApp = AXUIElementCreateApplication(pid)
        guard let allElements = flattenDockElements(root: dockApp) else {
            monLog.error("reloadDockElements: flatten returned nil")
            return
        }

        var newCache: [String: AXUIElement] = [:]
        var orderedDockApps: [AppBadgeInfo] = []

        for element in allElements {
            var title: AnyObject?
            guard AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title) == .success,
                  let titleStr = title as? String, !titleStr.isEmpty else { continue }

            if let app = resolveDockTitle(titleStr, element: element) {
                if newCache[app.bundleID] == nil {
                    newCache[app.bundleID] = element
                    orderedDockApps.append(app)
                }
            }
        }

        dockAppElements = newCache
        dockApps = orderedDockApps
    }

    private func flattenDockElements(root: AXUIElement) -> [AXUIElement]? {
        var childrenCount: CFIndex = 0
        var err = AXUIElementGetAttributeValueCount(root, "AXChildren" as CFString, &childrenCount)
        var result: [AXUIElement] = []

        if case .success = err {
            var subElements: CFArray?
            err = AXUIElementCopyAttributeValues(root, "AXChildren" as CFString, 0, childrenCount, &subElements)
            if case .success = err {
                if let children = subElements as? [AXUIElement] {
                    result.append(contentsOf: children)
                    for child in children {
                        if let nestedChildren = flattenDockElements(root: child) {
                            result.append(contentsOf: nestedChildren)
                        }
                    }
                }
                return result
            }
        }

        monLog.error("flattenDockElements: error \(err.rawValue) reading AXChildren")
        return nil
    }

    private func resolveDockTitle(_ title: String, element: AXUIElement) -> AppBadgeInfo? {
        if let bid = bundleIDFromElement(element) {
            monLog.info("resolveDockTitle '\(title, privacy: .public)' → bundleID \(bid, privacy: .public)")
            if let running = availableApps.first(where: { $0.bundleID == bid }) {
                return running
            }
            var icon: NSImage?
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
                icon = NSWorkspace.shared.icon(forFile: url.path)
            }
            return AppBadgeInfo(bundleID: bid, name: title, icon: icon)
        }

        if let app = availableApps.first(where: { $0.name == title }) {
            monLog.info("resolveDockTitle '\(title, privacy: .public)' → matched running app: \(app.bundleID, privacy: .public)")
            return app
        }

        for app in availableApps {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID),
                  let bundle = Bundle(url: url) else { continue }
            let cfName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            if cfName == title {
                monLog.info("resolveDockTitle '\(title, privacy: .public)' → matched by CFBundleName: \(app.bundleID, privacy: .public)")
                return app
            }
        }

        if let (bundleID, name) = installedAppRegistry[title] {
            monLog.info("resolveDockTitle '\(title, privacy: .public)' → matched installed registry: \(bundleID, privacy: .public)")
            var icon: NSImage?
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                icon = NSWorkspace.shared.icon(forFile: url.path)
            }
            return AppBadgeInfo(bundleID: bundleID, name: name, icon: icon)
        }

        monLog.warning("resolveDockTitle '\(title, privacy: .public)' → no match found")
        return nil
    }

    private func bundleIDFromElement(_ element: AXUIElement) -> String? {
        var value: AnyObject?

        if AXUIElementCopyAttributeValue(element, "AXFilename" as CFString, &value) == .success,
           let path = value as? String, let bundle = Bundle(path: path) {
            return bundle.bundleIdentifier
        }

        if AXUIElementCopyAttributeValue(element, kAXURLAttribute as CFString, &value) == .success {
            let url: URL
            if let u = value as? URL {
                url = u
            } else if let s = value as? String {
                url = URL(fileURLWithPath: s)
            } else {
                return nil
            }
            if let bundle = Bundle(url: url) {
                return bundle.bundleIdentifier
            }
        }

        return nil
    }

    private func readBadges() {
        var counts: [String: Int] = [:]
        for (bundleID, element) in dockAppElements {
            var label: AnyObject?
            guard AXUIElementCopyAttributeValue(element, "AXStatusLabel" as CFString, &label) == .success,
                  let text = label as? String, !text.isEmpty,
                  let count = Int(text) else { continue }
            counts[bundleID] = count
        }
        badges = counts
    }

    private func getDockPID() -> pid_t {
        NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == "com.apple.dock" })?
            .processIdentifier ?? 0
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
