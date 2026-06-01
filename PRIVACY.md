# Privacy Policy — Kabelwächter

Effective: 2026-06-01

Kabelwächter ("the app") is an open-source WireGuard VPN client for iPhone, iPad, Mac and Apple TV. It does **not** collect personal data, does **not** include analytics or crash-reporting SDKs, does **not** contain advertising, and is **not** backed by a server operated by the developer.

## Data the app handles

- **Tunnel configurations** (interface keys, peer keys, allowed-IPs, endpoint addresses): stored locally on the device by SwiftData and replicated to your own private iCloud database (CloudKit) so other Apple devices signed into the same Apple ID can see them. The developer has no access to this data. iCloud handling is governed by Apple's privacy terms.
- **Device identity**: a randomly-generated UUID and a user-editable device name (e.g. "John's iPhone") are stored locally and replicated to your private iCloud database so other Apple devices can show which device a tunnel currently belongs to.
- **VPN connection state and live statistics** (RX/TX bytes, last handshake): displayed on-device only; not transmitted anywhere by the app.

## Data the app does **not** collect

- No usage analytics, no diagnostics, no crash reporting SDK.
- No advertising or tracking identifiers.
- No third-party SDKs that collect data.
- No remote server operated by the developer of Kabelwächter.

## Sharing

The app shares no data with third parties. iCloud sync is between your own devices (same Apple ID) via Apple's infrastructure and is governed by Apple's privacy policy.

VPN traffic itself is routed to the WireGuard server you configure. That server's operator is responsible for any logging on the server side. The Kabelwächter developer has no relationship with the servers users connect to.

## Children

The app is not directed at children. No age-gating is needed because no personal data is collected.

## Open source

Kabelwächter is MIT-licensed. The full source — including everything that reads or writes data — is available at https://github.com/JxxKal/Kabelwaechter.

## Contact

Questions or concerns: mail@jankaluza.de

## Changes

Updates to this policy will be committed to this file. The App Store listing's Privacy Policy URL points to the most recent version on the `main` branch.
