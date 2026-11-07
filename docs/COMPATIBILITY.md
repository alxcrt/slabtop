# Compatibility and test status

HalfBook targets Apple Silicon MacBooks with wired external monitors and TVs. It is an early release with limited hardware evidence. Support for a Mac's display connector does not establish that every configuration works with this app.

## macOS support

HalfBook runs on macOS 14 or later on Apple Silicon. M1 and later chips are eligible, including MacBook Air, MacBook Pro, and desktop Macs. Desktop Macs usually have no internal display to disconnect.

There is no chip-model or macOS-version allowlist. The app checks for the native display functions it needs and verifies the external desktop before disconnecting an internal output. If a required function is missing, the app stays read-only. The app does not block future macOS releases by version number. Function detection alone does not establish compatibility because Apple can change these private functions. Compatibility tests below distinguish observed behavior from intended support.

## Display selection

| Configuration | Current scope |
| --- | --- |
| Identifiable wired monitors and TVs | Eligible for external-only mode when native display capabilities are available. |
| One wired TV waiting at the desktop chooser | The app attempts desktop activation before disconnecting the built-in display. |
| Multiple identifiable wired external displays | All stay active. Their relative positions stay intact. macOS enforces the Mac model's output limit. |
| Active or online unknown, virtual, AirPlay, or other wireless output | Automatic changes pause. |
| Ambiguous or missing physical display identity | No automatic target is selected. |
| Intel Mac | Outside the target hardware scope. |

A wired display must match a physical display identity reported by the Apple Silicon display controller. The app does not treat every non-built-in display as a wired screen. A dock that supplies a virtual display may therefore fall outside this scope.

## Recorded evidence

Evidence current on 7 November 2026. Pending means there is no completed result recorded here.

| Check | Result |
| --- | --- |
| LG C2 stuck at the macOS TV chooser, M2 MacBook Air, macOS 27.2 | A direct native API experiment activated the TV. BetterDisplay then disconnected the built-in display. macOS reported an unmirrored 3840 × 2160 desktop at 60 Hz, and the owner confirmed the picture. This was not a full HalfBook app test. |
| Packaged HalfBook manual apply and software restore on M2 Max MacBook Pro, macOS 27.2, with one wired display | Verified locally. The external desktop remained at 3440 × 1440 and 100 Hz through apply and restore. |
| Packaged HalfBook with two wired external displays on M2 Max, macOS 27.2 | Verified. Portrait 1440 × 2560 and ultrawide 3440 × 1440 stayed active at 60 Hz. Exact display modes and relative positions were preserved. Built-in output was off. The app recovery button restored built-in output; the original arrangement was restored and checked. |
| Policy, display engine, and layout unit tests | 47 tests passed with `swift test`. These tests use simulated display state. |
| HalfBook manual apply and software restore on M2 MacBook Air with LG C2 | Pending. |
| Keyboard recovery | Focused app menu shortcut verified. Global delivery from the automated UI tool did not trigger recovery; physical keyboard testing remains pending. Use the app window or menu bar as a fallback. |
| Automatic mode after physical cable reconnect | Pending. |
| Automatic mode after sleep and wake | Pending. |
| Start at login after a fresh login or restart | Pending. |
| First launch of the downloaded, quarantined release on a separate Mac | Pending. |
| Other Apple Silicon generations and display combinations | Pending. |

Policy unit tests cover decisions about safe targets. They do not prove cable reconnect, wake, login, or visible picture behavior. See [Contributing](../CONTRIBUTING.md) for a hardware test report checklist.

## Hardware and startup limits

HalfBook runs after login. It cannot run before FileVault unlock, during startup selection, or in macOS Recovery. FileVault remains enabled. Apple explains that FileVault protects access with the user's login password in its [FileVault guide](https://support.apple.com/guide/mac-help/protect-data-on-your-mac-with-filevault-mh11785/mac).

The app changes the desktop arrangement. It does not repair panel hardware, emulate lid sensors, prevent sleep, or change power management. A physically removed display assembly can affect the camera, microphones, antennas, or sensors, depending on the model and removal. Those effects need hardware assessment.

For an intact MacBook used with its lid closed, Apple calls for power and an external keyboard and mouse in its [external display troubleshooting guide](https://support.apple.com/en-us/102501). Removing a display assembly is a different hardware condition. The app does not make a modified Mac equivalent to an intact closed MacBook.

Apple specifies one external display up to 6K at 60 Hz for the [M2 MacBook Air](https://support.apple.com/en-us/111867). Disabling the built-in display does not establish support for another external display or a higher output mode.

The whole connection determines resolution and refresh rate. Check the Mac model, port, dock, adapter, cable, and TV. The recorded C2 result was 4K at 60 Hz. HalfBook does not promise 4K at 120 Hz, change adapter firmware, or override a display's identity.

## Signing

The release is ad hoc signed, without a Developer ID signature or Apple notarization. Apple Development signing credentials are not a substitute for Developer ID distribution. Follow the per-app first-launch steps in the [user guide](USER-GUIDE.md#open-the-download).
