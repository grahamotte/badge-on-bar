import SwiftUI
import AppKit

private let configWindowID = "config"

@main
struct BadgeOnBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("Badge on Bar", id: configWindowID) {
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
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarManager = StatusBarManager(settings: settings, monitor: monitor)
        statusBarManager?.onShowConfig = { [weak self] in self?.showConfigWindow() }
        monitor.start()
        PermissionsManager.checkOrPrompt()
        attachWindowDelegate()
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
        return false
    }

    func showConfigWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.identifier?.rawValue == configWindowID {
            window.makeKeyAndOrderFront(nil)
            return
        }
    }

    private func attachWindowDelegate() {
        for window in NSApp.windows where window.identifier?.rawValue == configWindowID {
            window.delegate = self
            window.isReleasedWhenClosed = false
            showConfigWindow()
            return
        }
    }
}
