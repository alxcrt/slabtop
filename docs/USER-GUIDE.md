# Use your external screens

Slabtop works inside your logged-in macOS session. Arrange access to that session before setup if the built-in screen is unusable. The app cannot make the FileVault startup screen appear on a particular display.

## Open the download

The current release is ad hoc signed. It has no Developer ID signature or Apple notarization.

1. Download the DMG from the [Slabtop releases page](https://github.com/alxcrt/slabtop/releases/latest).
2. Open the DMG.
3. Drag **Slabtop.app** onto **Applications** in the installer window.
4. Open the app from **Applications**.

If macOS blocks the app and you trust this download, use Apple's per-app exception procedure.

1. Open **System Settings**.
2. Click **Privacy & Security**.
3. Scroll to the message about Slabtop.
4. Click **Open Anyway**.
5. Confirm **Open** when macOS asks.

Apple documents this procedure in [Safely open apps on your Mac](https://support.apple.com/en-us/102445). If macOS gives a different warning or does not offer the exception, follow that warning and report the exact text. Do not disable Gatekeeper or other Mac security settings globally.

## Move the desktop to your screens

1. Turn on your external monitors or TVs.
2. Select their connected inputs.
3. Connect their video cables to the Mac.
4. If macOS asks to allow the accessory, approve that connection.
5. Open Slabtop from its display icon in the menu bar.
6. Click **Use external screens**.

Wait for the app to report that your desktop is on the external screens. Slabtop disconnects the built-in display in software only after all identified wired external desktops become active. It preserves their relative arrangement and keeps an existing external main screen. Set your preferred arrangement in **Display settings…** before applying.

If the TV is stuck at the macOS sharing or desktop chooser, use **Use external screens** or press **Control + Option + Command + E**. Slabtop attempts to activate the wired TV as an extended desktop before disconnecting the built-in display.

## Keep the setup automatic

1. Turn on **Use automatically**.
2. Turn on **Open at login**.
3. If macOS requests approval, allow the app in **System Settings > General > Login Items**.

Closing the app window keeps the app running in the menu bar. Automatic mode checks the connected displays every five seconds and responds to display and wake events. A connection can need several seconds to settle.

If BetterDisplay has an automatic rule that disconnects or reconnects the built-in display, turn off that rule. Two apps changing the same display can undo each other's work.

Turning off **Use automatically** stops future automatic changes. It does not re-enable the built-in display.

## Use virtual screens such as VITURE SpaceWalker

Some apps add virtual screens. VITURE SpaceWalker does this to show several screens in its glasses. By default Slabtop pauses while such a screen is active, so the built-in display can stay on after a restart or wake.

1. Turn on **Allow virtual screens**.
2. Keep **Use automatically** on.
3. Connect the glasses or other wired screen directly to the Mac.
4. Open the virtual-screen app.

Slabtop then turns the built-in display off whenever a wired screen is active. It leaves the virtual screens, their layout and the main screen to the other app. If a wired screen is mirroring, Slabtop does nothing until mirroring stops.

## Pause and restore the built-in display

1. Click **Restore built-in screen**, or press **Control + Option + Command + B**.
2. Read the result in the app window.

This action pauses automatic mode before requesting the software restore. A removed screen, damaged panel, or missing display identity cannot become usable through software.

**Quit Slabtop** stops monitoring. Quitting does not request a display restore. Use **Restore built-in screen** first if that is the result you want.

## Resolve a blank external screen

1. Check that the screen is powered on and uses the correct input.
2. Check both ends of the video cable.
3. If you use a dock or adapter, try a direct connection supported by your Mac.
4. Stop AirPlay, Sidecar, or virtual display sessions if Slabtop reports another display in use.
5. Press **Control + Option + Command + E** while Slabtop runs.

If the app reports read-only mode, check the [display capability requirements](COMPATIBILITY.md#macos-support). If it cannot identify a safe wired target, it keeps the built-in display available rather than guessing.

For cable, adapter, resolution, and accessory approval problems, follow Apple's [external display troubleshooting](https://support.apple.com/en-us/102501). Slabtop cannot repair a failed cable or bypass an accessory approval prompt.

If you lose all visible output, use an already configured remote access method if available. If the built-in screen still works, the restore shortcut may bring it back. The app cannot guarantee recovery when no usable screen or remote connection exists.

## Adjust picture quality

Click **Display settings…** to open macOS display settings. Choose the resolution, refresh rate, scaling, and HDR settings there. Slabtop does not select those modes.

For a TV, consult its manual for a PC input mode and full chroma support, often called 4:4:4, so text remains sharp. The right options depend on the TV and connection. A TV's 4K at 120 Hz support does not mean every Mac, adapter, dock, or cable can provide that mode.

## Remove the app

1. Turn off **Open at login**.
2. Click **Restore built-in screen** if you want the built-in display re-enabled in software.
3. Choose **Quit Slabtop** from its menu bar menu.
4. Move **Slabtop.app** from **Applications** to the Trash.

## Update from HalfBook

Quit HalfBook before installing Slabtop. Replace it with Slabtop in Applications, then open Slabtop. Existing automatic-mode settings are retained. Enable **Open at login** in Slabtop and verify the switch after the update. Move the old HalfBook app out of Applications so it cannot be launched by mistake.
