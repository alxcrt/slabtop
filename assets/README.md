# Slabtop artwork

`AppIcon.png` is the original 1024-pixel Slabtop icon. A silver keyboard and trackpad deck fills a blue and teal tile. The perspective, rounded aluminum body, dark keys, exposed hinge recess, and front bevel describe a MacBook with its lid removed.

The editable vector master is [`../scripts/make-icon.swift`](../scripts/make-icon.swift). It draws AppKit paths and gradients. Deck details share one perspective projection. The artwork uses no external images, fonts, text, or brand marks.

Regenerate the PNG and a macOS icon file from the project root.

```sh
swift scripts/make-icon.swift /tmp/Slabtop.icns
```

The icon file contains 16, 32, 128, 256, and 512-point representations at 1x and 2x. The generator also updates `assets/AppIcon.png`.

The artwork is part of this project and uses the project's license.
