# VBRecorder

`VBRecorder` is a macOS menu bar app for capturing the currently selected word from any app and storing it in a local CSV file.

## Quick Start

Build and run locally:

```bash
./scripts/dev-build-install-run.sh
```

Run tests:

```bash
./scripts/dev-test.sh
```

Build a local DMG:

```bash
./scripts/release-dmg.sh
```

## Release and Download

- GitHub Actions builds on every push to `main`
- The latest prerelease asset is published under `main-latest`
- The static download page is served from GitHub Pages:
  `https://gfiutchkuub.github.io/VBRecorder/`

## Accessibility

Grant Accessibility access once for:

```text
/Users/qiaqia/Applications/VBRecorder.app
```

Without this permission, the app cannot read selected text from other apps.

## Docs

- [Development](./docs/development.md)
- [Codebase](./docs/codebase.md)
- [Download Page](./docs/index.html)
