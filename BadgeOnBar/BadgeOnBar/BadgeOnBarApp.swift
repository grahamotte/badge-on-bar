import SwiftUI
import AppKit

@main
struct BadgeOnBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("Badge on Bar", id: "config") {
            ConfigurationView()
                .environment(appDelegate.settings)
                .environment(appDelegate.monitor)
        }
        .windowResizability(.contentSize)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let settings = AppSettings()
    let monitor = BadgeMonitor()
    private var statusBarManager: StatusBarManager?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarManager = StatusBarManager(settings: settings, monitor: monitor)
        monitor.start()
        PermissionsManager.checkOrPrompt()

        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.async { [weak self] in
            self?.attachWindowDelegate()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showConfigWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
        return false
    }

    func showConfigWindow() {
        NSApp.setActivationPolicy(.regular)
        if let window = NSApp.windows.first(where: { $0.title == "Badge on Bar" }) {
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func attachWindowDelegate() {
        for window in NSApp.windows where window.title == "Badge on Bar" {
            window.delegate = self
            window.isReleasedWhenClosed = false
            window.makeKeyAndOrderFront(nil)
            return
        }
    }
}
