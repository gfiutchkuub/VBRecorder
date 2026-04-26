import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @StateObject private var recorder = WordRecorder.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Settings")
                .font(.title2)
                .bold()

            HStack {
                Text("Shortcut")
                    .font(.headline)
                Spacer()
                KeyboardShortcuts.Recorder(for: .recordSelectedText) { shortcut in
                    recorder.handleShortcutChange(shortcut)
                }
            }

            Text(recorder.shortcutDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("Access")
                    .font(.headline)
                Spacer()
                Text(recorder.accessibilityStatusText)
                    .foregroundStyle(recorder.isAccessibilityAuthorized ? .green : .secondary)
            }

            if !recorder.isAccessibilityAuthorized {
                Button {
                    recorder.requestAccessibilityPermission()
                } label: {
                    Label("Enable", systemImage: "hand.raised")
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("File")
                    .font(.headline)

                HStack(spacing: 10) {
                    Image(systemName: "doc.text")
                        .imageScale(.large)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(recorder.recordFileURL.lastPathComponent)
                            .font(.body)

                        Text(recorder.displayPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }
            }

            HStack {
                Button {
                    recorder.chooseRecordFile()
                } label: {
                    Label("Choose", systemImage: "folder")
                }

                Button {
                    recorder.revealRecordFile()
                } label: {
                    Label("Open", systemImage: "magnifyingglass")
                }

                Spacer()

                Button("Reset") {
                    recorder.useDefaultRecordFile()
                }
                .disabled(recorder.isUsingDefaultFile)
            }

            if let statusMessage = recorder.statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}

extension KeyboardShortcuts.Name {
    static let recordSelectedText = Self(
        "recordSelectedText",
        default: .init(.r, modifiers: [.control, .option, .command])
    )
}
