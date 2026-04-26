# Codebase

## Top Level

- `VBRecorder/`
  App source code.
- `VBRecorderTests/`
  Unit tests.
- `VBRecorder.xcodeproj/`
  Xcode project configuration.
- `scripts/`
  Local build, test, and packaging scripts.
- `docs/`
  GitHub Pages site and project documentation.
- `.github/workflows/`
  CI and Pages workflows.

## Main App Files

- `VBRecorder/VBRecorderApp.swift`
  SwiftUI app entry point.
- `VBRecorder/AppDelegate.swift`
  Menu bar icon, menu items, shortcuts, and app lifecycle integration.
- `VBRecorder/WordRecorder.swift`
  Main record flow.
- `VBRecorder/WordRecordStore.swift`
  CSV storage, deduplication, and rank updates.
- `VBRecorder/WordNormalizer.swift`
  Input normalization rules.
- `VBRecorder/SelectedTextReader.swift`
  Reads selected text from the frontmost app.
- `VBRecorder/PasteboardSnapshot.swift`
  Preserves and restores pasteboard content when copy fallback is used.
- `VBRecorder/SettingsView.swift`
  Settings UI.
- `VBRecorder/SettingsWindowController.swift`
  Settings window host.

## Assets

- `VBRecorder/Assets.xcassets/AppIcon.appiconset/icon-source.svg`
  Source SVG for the app icon.
- `source/icon.svg`
  Original icon source kept outside the asset catalog.
