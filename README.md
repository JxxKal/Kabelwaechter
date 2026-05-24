# Kabelwaechter

WireGuard VPN client for **Apple TV** with an **iOS companion app** for tunnel
configuration and management.

> Powered by [WireGuard](https://www.wireguard.com/). WireGuard is a registered
> trademark of Jason A. Donenfeld.

## Status

**Phase 1 — Foundation Setup, in progress.**

The project is in the project-skeleton stage. Tunnel functionality and the
actual VPN data path are scheduled for Phase 2.

## Architecture overview

Two Apple-platform apps, one supporting Swift package, and one WireGuard fork:

| Component | Role |
|---|---|
| `KabelwaechtertvOS` (Apple TV app) | Lists tunnels, activates/deactivates VPN |
| `KabelwaechterNEtvOS` (Network Extension) | Packet Tunnel Provider, runs WireGuard tunnel |
| `KabelwaechteriOS` (iPhone companion) | Edits tunnel configs, no VPN itself |
| `KabelwaechterCore` (Swift package) | Shared constants + future shared model code |
| [`JxxKal/wireguard-apple-tvos`](https://github.com/JxxKal/wireguard-apple-tvos) | Fork of `natesinnott/wireguard-apple-tvos`, with `.v17` platform downgrade for our deployment target |

Tunnel-configuration metadata syncs between iPhone and Apple TV via **CloudKit
Private Database** (SwiftData with CloudKit backing).

Each device generates and stores its **own WireGuard keypair locally** — private
keys never leave the device they were created on. Each Apple-TV / iPhone shows
up to the WireGuard server as its own peer.

## Requirements

- macOS 14 (Sonoma) or newer
- Xcode 15 or newer
- Swift 5.9+
- Apple Developer Program enrolment (paid €99/year — App Groups, Network
  Extensions, iCloud Container and CloudKit are not available on free accounts)
- Apple TV 4K (1st gen, 2017) or newer, running tvOS 17+
- iPhone running iOS 17+

## Repository layout

```
Kabelwaechter/
├── KabelwaechteriOS/          (iOS app target, Phase 1)
├── KabelwaechtertvOS/         (tvOS app target, Phase 1)
├── KabelwaechterNEtvOS/       (tvOS Network Extension target, Phase 1)
├── KabelwaechterCore/         (Swift package: shared code)
└── Kabelwaechter.xcodeproj/   (Xcode project, Phase 1)
```

`Plan.md` is the current working plan but is `.gitignore`'d — the canonical
plan lives in an internal wiki.

## Localization

App UI and metadata: bilingual **German** and **English** from day one
(`Localizable.xcstrings`).

## License

Released under the [MIT License](LICENSE).
