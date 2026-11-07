# HalfBook artwork

`AppIcon.png` is the original 1024-pixel HalfBook icon. The silver laptop has no lid, a cable connects its exposed base to an external display, and a half sun echoes the app's name.

The editable vector master is [`../scripts/make-icon.swift`](../scripts/make-icon.swift). It draws with AppKit paths and gradients. The artwork uses no external images, fonts, or brand marks.

Regenerate the PNG and a macOS icon file from the project root.

```sh
swift scripts/make-icon.swift /tmp/HalfBook.icns
```

The icon file contains 16, 32, 128, 256, and 512-point representations at 1x and 2x. The generator also updates `assets/AppIcon.png`.

The artwork is part of this project and uses the project's license.
