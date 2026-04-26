import AppKit
import ApplicationServices
import Carbon.HIToolbox

enum SelectedTextReader {
    private static let copyKeyCode = CGKeyCode(kVK_ANSI_C)

    static func selectedText() -> String? {
        if let accessibilityText = selectedTextFromAccessibility() {
            return accessibilityText
        }

        return selectedTextByCopying()
    }

    private static func selectedTextFromAccessibility() -> String? {
        let systemWideElement = AXUIElementCreateSystemWide()

        var focusedElement: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard focusedResult == .success,
              let focusedElement,
              CFGetTypeID(focusedElement) == AXUIElementGetTypeID() else {
            return nil
        }

        let element = focusedElement as! AXUIElement

        var selectedText: CFTypeRef?
        let selectedResult = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )

        guard selectedResult == .success,
              let text = selectedText as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return text
    }

    private static func selectedTextByCopying() -> String? {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        let previousChangeCount = pasteboard.changeCount

        sendCopyKeystroke()

        let deadline = Date().addingTimeInterval(0.35)
        var copiedText: String?

        repeat {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))

            guard pasteboard.changeCount != previousChangeCount else {
                continue
            }

            let text = pasteboard.string(forType: .string)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let text, !text.isEmpty {
                copiedText = text
            }

            break
        } while Date() < deadline

        snapshot.restore(to: pasteboard)
        return copiedText
    }

    private static func sendCopyKeystroke() {
        let source = CGEventSource(stateID: .combinedSessionState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: copyKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: copyKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }
}
