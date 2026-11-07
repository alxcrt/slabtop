# Contribute to Slabtop

Start with the [compatibility record](docs/COMPATIBILITY.md). Display-control changes need hardware evidence because the private APIs can return success without producing a usable desktop.

## Build the app

Use an Apple Silicon Mac with a Swift 6 toolchain. The package currently uses Swift 5 language mode. Xcode command line tools must provide `swift`, `codesign`, and the macOS SDK.

Run these commands from the repository root.

```sh
swift test
./scripts/build-app.sh
```

The build script creates `dist/Slabtop.app`, versioned ARM64 DMG and ZIP downloads, and `dist/SHA256SUMS.txt`. It defaults to ad hoc signing. A local Apple Development identity does not provide a notarized public release.

Use `VERSION` to set the bundle and archive version. Distribution with a Developer ID identity also requires a separate, verified notarization process. The current build script does not perform notarization.

## Report a display problem

Open a [GitHub issue](https://github.com/alxcrt/slabtop/issues) with the following information.

- Mac model and chip, without a serial number.
- macOS version.
- App version.
- Monitor or TV model.
- Cable, adapter, and dock models.
- Whether another app manages display connections.
- The steps, visible result, and exact app message.
- Whether the same connection works in macOS display settings.

Remove private addresses, account names, serial numbers, and unrelated windows from screenshots or diagnostics. Do not upload full system or preference dumps.

## Validate a display-control change

Test with a usable recovery display or an already configured remote connection. Keep FileVault and Mac security settings enabled.

Record the manual external-only action, software restore, refusal with unknown or wireless outputs, physical reconnect, sleep and wake, and a fresh login. For multiple wired screens, verify that all stay active, the existing external main screen stays main, and relative positions stay intact. Include the actual visible picture, active display state, and observed resolution and refresh rate. Mark skipped checks as pending. A successful API return code or passing unit test is not a hardware result.

Record the macOS version and those results for each hardware test. Keep per-display resolution, refresh rate, HDR, and user power settings unchanged. Do not use a version-number change alone as evidence of compatibility.

## Keep changes focused

Keep target selection in `Policy.swift`, display operations in `DisplayEngine.swift`, and app controls in `App.swift`. Preserve activation and verification of all identified wired screens before disconnecting built-in output. Keep the external main screen, relative display positions, and selected display modes intact. Add behavior tests for new policy decisions.

Contributions use the repository's [MIT license](LICENSE).

## Read-only diagnostics

For a development build, run `swift run HeadlessMac --diagnostics`. For an installed app, run `/Applications/Slabtop.app/Contents/MacOS/HeadlessMac --diagnostics`. This reports capabilities, automatic mode, native login status, and display state without changing settings. Device identity strings and serial numbers are omitted.

Display-control failures are also recorded in the native macOS unified log under subsystem `com.alxcrt.HalfBook`, category `Displays`.

Slabtop was previously named HalfBook. Its bundle identifier and preferences domain remain `com.alxcrt.HalfBook` so updates retain settings and native login registration. The existing Application Support lock path is retained to serialize updates with an older running copy.
