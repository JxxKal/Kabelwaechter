# Kabelwächter · Xcode Handoff

Drop-in design tokens and color catalog for the iOS + tvOS app.

## What's in here

```
xcode-handoff/
├── KabelwaechterUI/
│   ├── Tokens.swift              # Colors, fonts, metrics, motion (one file)
│   ├── Modifiers.swift           # .kwLabel(), .kwPanel(), .kwCornerFrame()
│   └── Primitives/
│       ├── StatusPill.swift
│       └── CornerFrame.swift
└── Colors.xcassets/
    └── KW/                       # Named colors — kw/bg0, kw/cyan, kw/signal, …
```

## How to use

1. **Create a shared Swift Package** in your workspace called `KabelwaechterUI`.
   File → New → Package → Multiplatform → Library.
2. Copy everything in `KabelwaechterUI/` into `Sources/KabelwaechterUI/`.
3. Drag `Colors.xcassets` into the package as a resource (add to `resources:` in
   `Package.swift` → `.process("Colors.xcassets")`).
4. In both the iOS and tvOS app targets, add `KabelwaechterUI` as a dependency.
5. In `Info.plist` for both targets set `UIUserInterfaceStyle = Dark` —
   the brand is dark-only.

```swift
import SwiftUI
import KabelwaechterUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: KW.Space.lg) {
            Text("SECURE TUNNEL ACTIVE")
                .kwLabel()
            StatusPill(state: .connected, label: "TUNNEL UP")
        }
        .padding(KW.Space.xl)
        .background(Color.kwBg0)
    }
}
```

## Platform deltas

The same tokens work on iOS and tvOS — the only thing that scales is the type
ramp. Use `KW.Font.titleTV` (76 pt) instead of `KW.Font.title` (32 pt) when
compiling for tvOS. The `KWFont.title` accessor picks the right one at compile
time via `#if os(tvOS)`.

## What's NOT in this package

* App icons (`AppIcon.appiconset`, `tvAppIcon.brandassets`) — drop the SVGs
  from `assets/` into the app targets, not the shared package.
* Custom fonts — SF Mono ships with every Apple OS via
  `.system(design: .monospaced)`. No font files needed.
* WireGuard kit — integrate via `NetworkExtension` /
  `NEPacketTunnelProvider` in the app target.

See `Kabelwächter — Xcode Handoff.html` in the project root for the full
visual handoff: tokens beside their Swift values, plus every Hi-Fi screen
mapped to its SwiftUI component tree.
