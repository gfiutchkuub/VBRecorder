import AppKit
import ApplicationServices
import Combine
import KeyboardShortcuts
import OSLog
import Security
import UniformTypeIdentifiers

enum WordRecordingResult {
    case saved(String, URL)
    case missingAccessibilityPermission
    case noSelectedText
    case invalidSelection
    case failed(String)

    var statusTitle: String {
        switch self {
        case .saved(let word, _):
            return word
        case .missingAccessibilityPermission:
            return "GRANT"
        case .noSelectedText:
            return "NO TEXT"
        case .invalidSelection:
            return "ONE WORD"
        case .failed:
            return "ERROR"
        }
    }

    var shouldBeep: Bool {
        switch self {
        case .saved:
            return false
        case .missingAccessibilityPermission, .noSelectedText, .invalidSelection, .failed:
            return true
        }
    }
}

enum AccessibilityAuthorizationStatus {
    case authorized
    case needsApproval
}

private enum ProtectedFolder: CaseIterable {
    case desktop
    case documents
    case downloads

    var displayName: String {
        switch self {
        case .desktop:
            return "Desktop"
        case .documents:
            return "Documents"
        case .downloads:
            return "Downloads"
        }
    }

    var searchPathDirectory: FileManager.SearchPathDirectory {
        switch self {
        case .desktop:
            return .desktopDirectory
        case .documents:
            return .documentDirectory
        case .downloads:
            return .downloadsDirectory
        }
    }

    var settingsHint: String {
        "Privacy & Security > Files and Folders > \(displayName)"
    }
}

@MainActor
final class WordRecorder: ObservableObject {
    static let shared = WordRecorder()

    @Published private(set) var recordFileURL: URL
    @Published private(set) var isUsingDefaultFile: Bool
    @Published private(set) var statusMessage: String?
    @Published private(set) var accessibilityStatus: AccessibilityAuthorizationStatus
    @Published private(set) var shortcutDescription: String

    private let store: WordRecordStore
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "VBRecorder", category: "WordRecorder")

    private func debugLog(_ message: String) {
        print("[WordRecorder] \(message)")
        logger.info("\(message, privacy: .public)")
    }

    convenience init() {
        self.init(store: WordRecordStore())
    }

    init(store: WordRecordStore) {
        self.store = store
        self.recordFileURL = store.currentFileURL
        self.isUsingDefaultFile = store.isUsingDefaultFile
        self.accessibilityStatus = AXIsProcessTrusted() ? .authorized : .needsApproval
        self.shortcutDescription = Self.currentShortcutDescription()
        debugLog("initialized executablePath=\(Bundle.main.executablePath ?? "unknown") bundlePath=\(Bundle.main.bundlePath) signing=\(Self.signingIdentitySummary())")
    }

    var displayPath: String {
        recordFileURL.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    var accessibilityStatusText: String {
        switch accessibilityStatus {
        case .authorized:
            return "Granted"
        case .needsApproval:
            return "Not Granted"
        }
    }

    var isAccessibilityAuthorized: Bool {
        accessibilityStatus == .authorized
    }

    @discardableResult
    func refreshAccessibilityStatus() -> AccessibilityAuthorizationStatus {
        accessibilityStatus = AXIsProcessTrusted() ? .authorized : .needsApproval
        debugLog("refreshAccessibilityStatus authorized=\(self.accessibilityStatus == .authorized)")
        return accessibilityStatus
    }

    @discardableResult
    func requestAccessibilityPermission() -> Bool {
        refreshAccessibilityStatus()

        guard !isAccessibilityAuthorized else {
            statusMessage = "Accessibility access is already enabled."
            debugLog("requestAccessibilityPermission already authorized")
            return true
        }

        debugLog("requestAccessibilityPermission signing=\(Self.signingIdentitySummary())")
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openAccessibilitySettings()
        refreshAccessibilityStatus()
        if Self.isAdHocSigned {
            statusMessage = "This debug build is ad hoc signed. In Xcode set Signing Team, rebuild, then grant Accessibility again."
        } else {
            statusMessage = "System Settings opened. Enable VBRecorder in Privacy & Security > Accessibility."
        }
        debugLog("requestAccessibilityPermission completed authorized=\(self.isAccessibilityAuthorized)")
        return isAccessibilityAuthorized
    }

    @discardableResult
    func recordSelectedText() -> WordRecordingResult {
        guard AXIsProcessTrusted() else {
            let didAuthorize = requestAccessibilityPermission()
            debugLog("recordSelectedText blocked accessibilityAuthorized=false requestedPermission didAuthorize=\(didAuthorize) signing=\(Self.signingIdentitySummary())")
            return didAuthorize ? recordSelectedText() : .missingAccessibilityPermission
        }

        guard let selectedText = SelectedTextReader.selectedText() else {
            statusMessage = "No selected text was found."
            debugLog("recordSelectedText no selected text")
            return .noSelectedText
        }

        guard let word = WordNormalizer.normalizedWord(from: selectedText) else {
            statusMessage = "Select exactly one word."
            debugLog("recordSelectedText invalid selection raw=\(selectedText)")
            return .invalidSelection
        }

        return appendWord(word)
    }

    func chooseRecordFile() {
        guard let url = presentRecordFilePanel(
            title: "Choose Record File",
            prompt: "Use File",
            message: "Choose the CSV file used for word recording.",
            suggestedURL: recordFileURL
        ) else {
            return
        }

        do {
            try useRecordFile(url)
            statusMessage = "Recording to \(url.lastPathComponent)."
        } catch {
            statusMessage = error.localizedDescription
            if case let WordRecordStoreError.accessDenied(deniedURL) = error {
                _ = recoverFileAccess(for: deniedURL)
            }
            NSSound.beep()
        }
    }

    func useDefaultRecordFile() {
        store.useDefaultFile()
        refreshFileState()
        statusMessage = "Recording to the default words.csv file."
    }

    func handleShortcutChange(_ shortcut: KeyboardShortcuts.Shortcut?) {
        refreshShortcutState()
        statusMessage = shortcut.map { "Shortcut updated to \($0)." } ?? "Shortcut cleared."
        debugLog("handleShortcutChange shortcut=\(shortcutDescription)")
        NotificationCenter.default.post(name: .recordShortcutDidChange, object: nil)
    }

    func revealRecordFile() {
        do {
            let url = try store.ensureCurrentFileExists()
            refreshFileState()
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch let error as WordRecordStoreError {
            if case let .accessDenied(url) = error, recoverFileAccess(for: url) {
                revealRecordFile()
                return
            }

            statusMessage = error.localizedDescription
            NSSound.beep()
        } catch {
            statusMessage = error.localizedDescription
            NSSound.beep()
        }
    }

    private func appendWord(_ word: String, allowAccessRecovery: Bool = true) -> WordRecordingResult {
        do {
            let url = try store.append(word)
            refreshFileState()
            statusMessage = "Saved \(word) to \(url.lastPathComponent)."
            debugLog("recordSelectedText saved word=\(word) file=\(url.path)")
            return .saved(word, url)
        } catch let error as WordRecordStoreError {
            debugLog("recordSelectedText store error=\(error.localizedDescription)")

            if case let .accessDenied(url) = error, allowAccessRecovery, recoverFileAccess(for: url) {
                return appendWord(word, allowAccessRecovery: false)
            }

            statusMessage = error.localizedDescription
            return .failed(error.localizedDescription)
        } catch {
            statusMessage = error.localizedDescription
            debugLog("recordSelectedText write failed error=\(error.localizedDescription)")
            return .failed(error.localizedDescription)
        }
    }

    private func useRecordFile(_ url: URL) throws {
        try store.setRecordFileURL(url)
        refreshFileState()
    }

    private func refreshFileState() {
        recordFileURL = store.currentFileURL
        isUsingDefaultFile = store.isUsingDefaultFile
    }

    private func refreshShortcutState() {
        shortcutDescription = Self.currentShortcutDescription()
    }

    private func recoverFileAccess(for deniedURL: URL) -> Bool {
        debugLog("recoverFileAccess requested file=\(deniedURL.path)")
        activateAppForPrompt()

        let message: String
        if let protectedFolder = Self.protectedFolder(containing: deniedURL) {
            message = "macOS blocked access to \(protectedFolder.displayName). Confirm the file again. If macOS already denied it once, VBRecorder will open Files and Folders settings next."
        } else {
            message = "VBRecorder needs access to this file. Confirm the file again to continue recording."
        }

        guard let selectedURL = presentRecordFilePanel(
            title: "Allow Record File Access",
            prompt: "Allow Access",
            message: message,
            suggestedURL: deniedURL
        ) else {
            statusMessage = "File access was not granted."
            return false
        }

        do {
            try useRecordFile(selectedURL)
            statusMessage = "Access granted for \(selectedURL.lastPathComponent)."
            debugLog("recoverFileAccess granted file=\(selectedURL.path)")
            return true
        } catch let error as WordRecordStoreError {
            statusMessage = error.localizedDescription
            debugLog("recoverFileAccess failed error=\(error.localizedDescription)")

            if case let .accessDenied(url) = error {
                openFileAccessSettings(for: url)
            }

            return false
        } catch {
            statusMessage = error.localizedDescription
            debugLog("recoverFileAccess failed error=\(error.localizedDescription)")
            return false
        }
    }

    private func presentRecordFilePanel(
        title: String,
        prompt: String,
        message: String,
        suggestedURL: URL
    ) -> URL? {
        let panel = NSSavePanel()
        panel.title = title
        panel.prompt = prompt
        panel.message = message
        panel.directoryURL = suggestedURL.deletingLastPathComponent()
        panel.nameFieldStringValue = suggestedURL.lastPathComponent.isEmpty ? "words.csv" : suggestedURL.lastPathComponent
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        return panel.runModal() == .OK ? panel.url : nil
    }

    private func activateAppForPrompt() {
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openAccessibilitySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension"
        ].compactMap(URL.init(string:))

        if let url = urls.first(where: { url in
            let opened = NSWorkspace.shared.open(url)
            self.debugLog("openAccessibilitySettings url=\(url.absoluteString) opened=\(opened)")
            return opened
        }) {
            _ = url
            return
        }

        debugLog("openAccessibilitySettings falling back to System Settings.app")
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: "/System/Applications/System Settings.app"),
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    private func openFileAccessSettings(for url: URL) {
        let protectedFolder = Self.protectedFolder(containing: url)
        let settingsDescription = protectedFolder?.settingsHint ?? "Privacy & Security > Files and Folders"

        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension"
        ].compactMap(URL.init(string:))

        if let settingsURL = urls.first(where: { candidate in
            let opened = NSWorkspace.shared.open(candidate)
            debugLog("openFileAccessSettings url=\(candidate.absoluteString) opened=\(opened)")
            return opened
        }) {
            _ = settingsURL
        } else {
            debugLog("openFileAccessSettings falling back to System Settings.app")
            NSWorkspace.shared.openApplication(
                at: URL(fileURLWithPath: "/System/Applications/System Settings.app"),
                configuration: NSWorkspace.OpenConfiguration()
            )
        }

        statusMessage = "System Settings opened. Enable VBRecorder in \(settingsDescription), or choose a file outside that folder."
    }

    private static var isAdHocSigned: Bool {
        signingIdentitySummary().contains("adhoc")
    }

    private static func currentShortcutDescription() -> String {
        KeyboardShortcuts.getShortcut(for: .recordSelectedText)
            .map { "Current shortcut: \($0)" } ?? "Current shortcut: none"
    }

    private static func protectedFolder(containing url: URL) -> ProtectedFolder? {
        let targetPath = url.standardizedFileURL.path

        return ProtectedFolder.allCases.first { folder in
            guard let baseURL = FileManager.default.urls(for: folder.searchPathDirectory, in: .userDomainMask).first else {
                return false
            }

            let basePath = baseURL.standardizedFileURL.path
            return targetPath == basePath || targetPath.hasPrefix(basePath + "/")
        }
    }

    private static func signingIdentitySummary() -> String {
        let adHocFlag: UInt32 = 0x2
        var staticCode: SecStaticCode?
        let executableURL = URL(fileURLWithPath: Bundle.main.executablePath ?? Bundle.main.bundlePath) as CFURL
        let createStatus = SecStaticCodeCreateWithPath(executableURL, [], &staticCode)

        guard createStatus == errSecSuccess, let staticCode else {
            return "unknown(create=\(createStatus))"
        }

        var signingInfo: CFDictionary?
        let infoStatus = SecCodeCopySigningInformation(staticCode, SecCSFlags(), &signingInfo)

        guard infoStatus == errSecSuccess,
              let info = signingInfo as? [String: Any] else {
            return "unknown(info=\(infoStatus))"
        }

        let flags = info[kSecCodeInfoFlags as String] as? UInt32 ?? 0
        let identifier = info[kSecCodeInfoIdentifier as String] as? String ?? "unknown"
        let teamIdentifier = info[kSecCodeInfoTeamIdentifier as String] as? String ?? "none"
        let signer = info[kSecCodeInfoFormat as String] as? String ?? "unknown"

        if flags & adHocFlag != 0 {
            return "adhoc id=\(identifier) team=\(teamIdentifier) format=\(signer)"
        }

        return "signed id=\(identifier) team=\(teamIdentifier) format=\(signer)"
    }
}

extension Notification.Name {
    static let recordShortcutDidChange = Notification.Name("VBRecorder_recordShortcutDidChange")
}
