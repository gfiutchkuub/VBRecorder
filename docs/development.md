# Development

## Local Workflow

Build and install the fixed local app bundle:

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

Build and publish a prerelease from local artifacts:

```bash
./scripts/publish-release.sh
```

## Fixed Local App Path

```text
/Users/qiaqia/Applications/VBRecorder.app
```

This fixed path keeps Accessibility permission stable across rebuilds.

## CI and Release

The repository keeps one GitHub Actions workflow:

- `pages.yml`
  Publishes the static download page from `docs/` to GitHub Pages.

Releases are published locally with GitHub CLI:

- `scripts/publish-release.sh`
  Builds `VBRecorder.dmg` and `VBRecorder-app.zip`, then creates or updates the
  `main-latest` prerelease.

## Notes

- GitHub Actions are only used for the Pages site
- A fully public macOS release still benefits from proper signing and notarization
