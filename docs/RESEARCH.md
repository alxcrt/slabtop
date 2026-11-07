# Why the app activates the external desktop first

A connected TV can exist in macOS display enumeration without an active desktop. Disabling the built-in display before the TV becomes active risks leaving the owner with no visible desktop.

## The LG C2 incident

On an M2 MacBook Air running macOS 27.2, an LG C2 remained at the macOS TV chooser instead of showing the desktop. Repeated enable-only requests returned success codes but did not make the TV active. A global TV behavior preference also failed to fix reconnect in that investigation.

A session display transaction that called `SLSConfigureDisplayIndependentOutput(config, externalID, 0)` and then enabled the external output activated the C2. BetterDisplay subsequently disconnected the built-in display. A fresh macOS display report showed the C2 as the main, online, unmirrored display at 3840 × 2160 and 60 Hz. The owner confirmed the visible desktop.

That experiment established the admission sequence. The packaged Slabtop app subsequently passed automatic external-only setup and an owner-confirmed physical C2 reconnect on the same Air, with BetterDisplay automatic connection rules off. It does not establish every TV or reconnect after a new login. The [compatibility record](COMPATIBILITY.md#recorded-evidence) separates those checks.

## The implementation

Slabtop uses Core Graphics to inspect display state and configure the desktop. It loads private SkyLight symbols for display enumeration, independent-output admission, and software display enablement.

The app identifies wired displays through positive matches against the physical display controller's product identity. Its policy admits each wired external desktop and rejects a competing active or online unknown output. It re-reads display state after admission before it disconnects the built-in display.

The app retains an existing external main screen. When the main screen changes, it translates all external display origins by the same amount so their relative positions stay intact. It retains the selected resolution, pixel dimensions, refresh rate, and mode flags. WindowServer can change modes and positions after built-in disconnection, so the app restores the saved settings in subsequent session transactions. Mode objects are reacquired from the current mode catalogue, including HiDPI entries, rather than reusing stale objects.

These private functions are not a supported Apple API contract. The app detects these functions at runtime instead of locking display control to a macOS version. It verifies the actual external desktop before disabling an internal output. Missing capabilities leave the app read-only. Future systems still need real hardware testing because Apple can change private APIs.

## Related projects

The following primary sources informed the investigation. Slabtop was written independently and does not include their code or require their binaries.

- [BetterDisplay](https://github.com/waydabber/BetterDisplay) documents software display connection management and automatic built-in disconnection on Apple Silicon. It also offers broader display controls beyond this app's scope.
- [displayplacer](https://github.com/jakehilborn/displayplacer) demonstrates the established use of macOS display configuration tools for arrangements and modes.
- [displaytoggle](https://github.com/calvincchan/displaytoggle) documents `SLSGetDisplayList` and `SLSConfigureDisplayEnabled` for built-in display control on Apple Silicon.
- [Clamless](https://github.com/TCXM/clamless) distinguishes the WindowServer desktop arrangement from panel power control. Slabtop changes the arrangement and makes no separate panel power-saving guarantee.

BetterDisplay is useful independently. Its automatic built-in connection rule should be off when Slabtop owns that rule, so the two apps do not issue conflicting requests.

## Apple's documented boundaries

Apple's [external display troubleshooting guide](https://support.apple.com/en-us/102501) covers cable capability, dock isolation, closed-lid accessories, and accessory approval. Those conditions can prevent output before an app has a useful desktop to manage.

Apple's [M2 MacBook Air specifications](https://support.apple.com/en-us/111867) list one external display up to 6K at 60 Hz. Software disconnection does not change the published hardware limit.

Apple's [FileVault guide](https://support.apple.com/guide/mac-help/protect-data-on-your-mac-with-filevault-mh11785/mac) explains the password requirement that protects encrypted data. Slabtop does not bypass that requirement or run at pre-login unlock.

Apple's [Gatekeeper guidance](https://support.apple.com/en-us/102445) describes per-app first-launch exceptions. The current release has no Apple notarization, so the user guide follows that procedure instead of changing global security policy.
