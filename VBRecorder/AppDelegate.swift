import Cocoa
import KeyboardShortcuts
import OSLog

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let statusSymbolName = "book"
    private var statusItem: NSStatusItem!
    private let recorder = WordRecorder.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "VBRecorder", category: "AppDelegate")
    private var shortcutDidChangeObserver: NSObjectProtocol?
    private var frontmostApplicationBeforeMenuTracking: NSRunningApplication?

    private func debugLog(_ message: String) {
        print("[AppDelegate] \(message)")
        logger.info("\(message, privacy: .public)")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        debugLog("applicationDidFinishLaunching bundle=\(Bundle.main.bundleIdentifier ?? "unknown") path=\(Bundle.main.bundlePath)")
        NSApp.setActivationPolicy(.accessory)
        setupStatusBar()
        _ = recorder.refreshAccessibilityStatus()
        setupKeyboardShortcut()
    }

    deinit {
        if let shortcutDidChangeObserver {
            NotificationCenter.default.removeObserver(shortcutDidChangeObserver)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        debugLog("applicationDidBecomeActive accessibilityAuthorized=\(self.recorder.isAccessibilityAuthorized)")
        _ = recorder.refreshAccessibilityStatus()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard statusItem.button != nil else { return }
        restoreStatusBarIcon()

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self

        let recordItem = NSMenuItem(
            title: "Record",
            action: #selector(recordSelectedText(_:)),
            keyEquivalent: ""
        )
        recordItem.target = self
        recordItem.setShortcut(for: .recordSelectedText)
        menu.addItem(recordItem)

        let revealItem = NSMenuItem(
            title: "Open File",
            action: #selector(revealRecordFile(_:)),
            keyEquivalent: ""
        )
        revealItem.target = self
        menu.addItem(revealItem)

        menu.addItem(NSMenuItem.separator())

        let requestItem = NSMenuItem(
            title: "Access",
            action: #selector(requestPermission(_:)),
            keyEquivalent: ""
        )
        requestItem.target = self
        menu.addItem(requestItem)

        let settingsItem = NSMenuItem(
            title: "Settings",
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quitApp(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        frontmostApplicationBeforeMenuTracking = NSWorkspace.shared.frontmostApplication
            .flatMap { application in
                application.processIdentifier == currentProcessIdentifier ? nil : application
            }
        debugLog("menuWillOpen frontmostApp=\(frontmostApplicationBeforeMenuTracking?.bundleIdentifier ?? "none")")
    }

    func menuDidClose(_ menu: NSMenu) {
        DispatchQueue.main.async {
            self.frontmostApplicationBeforeMenuTracking = nil
        }
    }

    private func setupKeyboardShortcut() {
        rebindKeyboardShortcut()

        shortcutDidChangeObserver = NotificationCenter.default.addObserver(
            forName: .recordShortcutDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebindKeyboardShortcut()
        }
    }

    private func rebindKeyboardShortcut() {
        KeyboardShortcuts.removeHandler(for: .recordSelectedText)
        KeyboardShortcuts.onKeyUp(for: .recordSelectedText) { [weak self] in
            self?.handleRecordSelectedText()
        }

        let shortcutDescription = KeyboardShortcuts.getShortcut(for: .recordSelectedText)
            .map(\.description) ?? "none"
        debugLog("rebindKeyboardShortcut shortcut=\(shortcutDescription)")
    }

    @objc private func requestPermission(_ sender: Any?) {
        let trusted = recorder.requestAccessibilityPermission()
        debugLog("requestPermission result trusted=\(trusted)")
        showTemporaryStatus(trusted ? "OK" : "GRANT")
    }

    @objc private func openSettings(_ sender: Any?) {
        debugLog("openSettings requested")
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)
        SettingsWindowController.shared.show()
    }

    @objc private func recordSelectedText(_ sender: Any?) {
        handleRecordSelectedTextFromMenu()
    }

    @objc private func revealRecordFile(_ sender: Any?) {
        recorder.revealRecordFile()
    }

    private func showTemporaryStatus(_ text: String) {
        let display = String(text.prefix(12))
        statusItem.button?.image = nil
        statusItem.button?.title = display

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.restoreStatusBarIcon()
        }
    }

    @objc private func quitApp(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func handleRecordSelectedTextFromMenu() {
        let applicationToReactivate = frontmostApplicationBeforeMenuTracking

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            if let applicationToReactivate {
                applicationToReactivate.activate(options: [.activateAllWindows])
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.handleRecordSelectedText()
            }
        }
    }

    private func handleRecordSelectedText() {
        let result = recorder.recordSelectedText()
        debugLog("handleRecordSelectedText status=\(result.statusTitle)")

        if result.shouldBeep {
            NSSound.beep()
        }

        showTemporaryStatus(result.statusTitle)
    }

    private func restoreStatusBarIcon() {
        guard let button = statusItem.button else { return }

        button.title = ""
        button.imagePosition = .imageOnly
        button.image = Self.statusBarImage()
        button.toolTip = "VBRecorder"

        if button.image == nil {
            button.title = "VB"
        }
    }

    private static func statusBarImage() -> NSImage? {
        let image = NSImage(
            systemSymbolName: statusSymbolName,
            accessibilityDescription: "VBRecorder"
        )
        image?.isTemplate = true
        image?.size = NSSize(width: 18, height: 18)
        return image
    }
}
