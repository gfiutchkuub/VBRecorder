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

## Fixed Local App Path

```text
/Users/qiaqia/Applications/VBRecorder.app
```

This fixed path keeps Accessibility permission stable across rebuilds.

## CI and Release

The repository includes two GitHub Actions workflows:

- `ci.yml`
  Runs tests and builds on every push to `main` and every pull request.
- `pages.yml`
  Publishes the static download page from `docs/` to GitHub Pages.

The `main` branch workflow also updates the `main-latest` prerelease and uploads:

- `VBRecorder.dmg`
- `VBRecorder-app.zip`

## Notes

- CI uses `CODE_SIGNING_ALLOWED=NO`
- CI artifacts are for verification and direct download
- A fully public macOS release still benefits from proper signing and notarization
