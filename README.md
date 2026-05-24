# Kabelwaechter

WireGuard VPN client for **Apple TV** with an **iOS companion app** for tunnel
configuration and management.

> Powered by [WireGuard](https://www.wireguard.com/). WireGuard is a registered
> trademark of Jason A. Donenfeld.

## Status

**Phase 3 — tvOS tunnel activation, code complete.**

End-to-end code path from `Verbinden` button → `NETunnelProviderManager` →
`PacketTunnelProvider` → `WireGuardAdapter.start(…)` is wired and builds clean
on iOS Simulator and tvOS device. The actual on-device VPN data-path
validation (Phase 3.4) requires a physical Apple TV — see
[Deploy & Test on Apple TV](#deploy--test-on-apple-tv).

## Architecture overview

Two Apple-platform apps, one Swift package with two products, one Network
Extension, and a WireGuard fork:

| Component | Role |
|---|---|
| `Kabelwaechter iOS` (iPhone companion) | Edits tunnel configs, no VPN itself (decision #8 — no Personal-VPN entitlement on iOS) |
| `Kabelwaechter tvOS` (Apple TV app) | Tunnel list, manual import, Connect/Disconnect |
| `KabelwaechterNEtvOS` (Network Extension) | Packet Tunnel Provider — runs the actual WireGuard tunnel |
| `KabelwaechterCore` (Swift package, library 1) | Domain types (TunnelConfiguration, wg-quick parser, KeychainStore) — **no WireGuardKit dependency** |
| `KabelwaechterPersistence` (Swift package, library 2) | SwiftData `@Model`s, `TunnelRepository`, CloudKit container factories |
| [`JxxKal/wireguard-apple-tvos`](https://github.com/JxxKal/wireguard-apple-tvos) | Fork of `natesinnott/wireguard-apple-tvos`, `.v17` platform downgrade |

Tunnel data is split structurally into a shared **TunnelTemplate** (synced via
CloudKit Private Database — server endpoint, public key, allowed IPs, DNS, MTU,
PSK) and a per-device **TunnelInstance** (stored in a separate local-only
`ModelContainer` — local interface address, listen port). The **private key**
itself never enters SwiftData — it lives in the Keychain with
`AccessibleAfterFirstUnlockThisDeviceOnly` and an App-Group access group so the
tvOS NE can read it. Each Apple-TV / iPhone shows up to the WireGuard server as
its own peer — see [ADR-0001](docs/adr/0001-tunnel-template-instance-split.md)
and [CONTEXT.md](CONTEXT.md) for terminology.

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
├── Kabelwaechter iOS/         Xcode project root
│   ├── Kabelwaechter iOS/     iOS app sources (Companion-Editor)
│   ├── Kabelwaechter tvOS/    tvOS app sources (VPN-Haupt-App)
│   ├── KabelwaechterNEtvOS/   tvOS Network Extension (Packet Tunnel)
│   └── Kabelwaechter.xcodeproj/
├── KabelwaechterCore/         Swift package (two library products)
│   ├── Sources/
│   │   ├── KabelwaechterCore/
│   │   └── KabelwaechterPersistence/
│   └── Tests/
├── Design/                    Logo SVGs, color tokens, app-icon sources
├── docs/adr/                  Architecture Decision Records
├── CONTEXT.md                 Domain glossary
└── README.md
```

`Plan.md` is the current working plan but is `.gitignore`'d — the canonical
plan lives in an internal wiki.

## Localization

App UI and metadata: bilingual **German** (source) and **English**
(`Localizable.xcstrings`).

## Deploy & Test on Apple TV

The tvOS Simulator [cannot run actual VPN](https://developer.apple.com/documentation/networkextension)
— Phase 3.4 validation needs real hardware.

### One-time setup

1. **Provisioning.** In the Apple Developer Portal make sure the four App IDs
   (`de.jankaluza.kabelwaechter.{ios,tv,tv.networkextension,ios.networkextension}`),
   the App Group `group.de.jankaluza.kabelwaechter.shared`, and the iCloud
   Container `iCloud.de.jankaluza.kabelwaechter.tunnels` exist with the
   capabilities listed in Plan §2.
2. **Sign-in on Apple TV.** Settings → Users and Accounts → Apple Account →
   sign in with the same Apple ID that the Apple Developer team uses. iCloud
   sync needs this; manual-import works without it.
3. **Pair Apple TV with Xcode.** On the Mac open Xcode → Window → Devices and
   Simulators → Apple TV row → tap *Pair* — confirm the 6-digit code on the
   TV. Pairing survives reboots; only redo it after a factory reset.
4. **Trust the developer.** First time a personal-team-signed build lands on
   the TV: Settings → General → Apps → Developer Apps → trust the team.

### Build & install

```
xcodebuild -project "Kabelwaechter iOS/Kabelwaechter.xcodeproj" \
           -scheme "Kabelwaechter tvOS" \
           -destination 'platform=tvOS,name=<Apple TV name>' \
           -configuration Debug \
           build
```

Or, in Xcode: select the `Kabelwaechter tvOS` scheme + the paired Apple TV in
the destination dropdown, then ⌘R. The Network Extension target
(`KabelwaechterNEtvOS`) is embedded automatically — confirm in the build log
that it lands at `Kabelwaechter tvOS.app/PlugIns/KabelwaechterNEtvOS.appex`.

### Get a tunnel onto the device

Two paths, depending on iCloud:

- **iCloud sync (preferred).** Set up the tunnel once on the iPhone Companion
  (`+` button → paste wg-quick → Save). CloudKit Private Database syncs the
  **TunnelTemplate** to the Apple TV within seconds. On the TV the tunnel
  shows up greyed-out ("not configured here") — tap it → use *Manuell*
  Import to drop in this device's wg-quick (with its own Address and Private
  Key) → the dot turns mint.
- **Manual on Apple TV.** Open the tvOS app → `+` button → paste the
  wg-quick directly (a Bluetooth keyboard paired to the TV is strongly
  recommended; the Siri Remote on-screen keyboard is painful for multi-line
  base64). Save.

### Connect

Pick the tunnel → tap **Verbinden**. The first time, tvOS prompts to add a
VPN configuration to Settings; approve it (Settings → General → VPN appears
afterwards as `<tunnel-name>`). Status label below the button transitions
`Getrennt → Verbindet… → Verbunden`. The status dot in the list view turns
mint and the chevron-shield icon on the detail button changes to the filled
shield.

To verify packets actually leave through the tunnel, open a browser-based IP
check on the Apple TV (e.g. via TVOS browser app, or check
`/var/log/system.log` of your WireGuard server for the new peer handshake).

### Debugging

The Network Extension logs are prefixed with `[KabelwaechterNE]`. Tail them
live from the Mac while the Apple TV is paired:

```
xcrun devicectl device process view --device <Apple TV name> KabelwaechterNEtvOS
```

Or in Xcode → Window → Devices and Simulators → open Console on the TV row.
Search for `KabelwaechterNE`. Expected log lines on a successful `Verbinden`:

```
[KabelwaechterNE] startTunnel — Bundle-ID: de.jankaluza.kabelwaechter.tv.networkextension
[KabelwaechterNE] Tunnel gestartet
```

Common failures:

| Symptom in Console | Likely cause |
|---|---|
| `kein wgQuickConfig in providerConfiguration` | App-side `TunnelManager.connect` didn't populate the dictionary — usually means the tunnel has no `TunnelInstance` locally yet. |
| `wgQuick-Parse fehlgeschlagen: invalidLine(…)` | The wg-quick that was pasted has a stray non-key/value line. Fix the source config and re-import. |
| `Core→WireGuardKit-Mapping fehlgeschlagen: invalidPrivateKey` | The Curve25519 key isn't 32 bytes after base64 decode — config is malformed. |
| `WireGuardAdapter.start Fehler: cannotLocateTunnelFileDescriptor` | NE booted before NEPacketTunnelFlow handed it a tunnel FD — usually a transient race; retry. If persistent, check the NE's entitlements (App Group + NetworkExtensions). |

### Resetting the on-device state

To wipe everything tvOS-side without uninstalling the app: Settings → General
→ VPN → tap the configuration → Remove. Then in the app: Tunnel → Detail →
*Tunnel löschen*. Re-import to test again.

## License

Released under the [MIT License](LICENSE).
