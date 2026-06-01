# Datenschutzerklärung — Kabelwächter

Stand: 01.06.2026

Kabelwächter („die App") ist ein quelloffener WireGuard-VPN-Client für iPhone, iPad, Mac und Apple TV. Die App **erhebt keine personenbezogenen Daten**, enthält **keine Analytics oder Crash-Reporting-SDKs**, **keine Werbung** und wird **nicht** durch einen vom Entwickler betriebenen Server unterstützt.

## Welche Daten die App verarbeitet

- **Tunnel-Konfigurationen** (Interface-Schlüssel, Peer-Schlüssel, AllowedIPs, Endpoint-Adressen): lokal auf dem Gerät via SwiftData gespeichert und in deine eigene private iCloud-Datenbank (CloudKit) repliziert, damit andere Apple-Geräte mit derselben Apple-ID sie sehen. Der Entwickler hat keinen Zugriff. Der Umgang mit iCloud richtet sich nach Apples Datenschutzbestimmungen.
- **Geräte-Identität**: eine zufällig erzeugte UUID und ein vom Benutzer editierbarer Geräte-Name (z. B. „Jans iPhone") werden lokal gespeichert und in deine private iCloud-Datenbank repliziert, damit andere Apple-Geräte anzeigen können, welchem Gerät ein Tunnel gerade gehört.
- **VPN-Status und Live-Statistik** (RX/TX-Bytes, letzter Handshake): wird ausschließlich auf dem Gerät angezeigt; die App überträgt diese Werte an keinen externen Empfänger.

## Welche Daten die App **nicht** erhebt

- Keine Nutzungs-Analytics, keine Diagnose-Daten, kein Crash-Reporting-SDK.
- Keine Werbe- oder Tracking-Identifier.
- Keine Drittanbieter-SDKs, die Daten sammeln.
- Kein vom Entwickler von Kabelwächter betriebener Remote-Server.

## Weitergabe

Die App gibt keine Daten an Dritte weiter. Der iCloud-Sync findet zwischen deinen eigenen Geräten (gleiche Apple-ID) über Apples Infrastruktur statt und unterliegt Apples Datenschutzbestimmungen.

Der VPN-Traffic selbst wird zu dem WireGuard-Server geleitet, den du konfigurierst. Was dieser Server protokolliert, liegt in der Verantwortung seines Betreibers. Der Entwickler von Kabelwächter steht in keinerlei Verhältnis zu den Servern, mit denen Benutzer sich verbinden.

## Kinder

Die App richtet sich nicht an Kinder. Eine Altersbeschränkung ist nicht erforderlich, da keine personenbezogenen Daten erhoben werden.

## Open Source

Kabelwächter ist MIT-lizensiert. Der vollständige Quellcode — inklusive aller Stellen, die Daten lesen oder schreiben — ist unter https://github.com/JxxKal/Kabelwaechter einsehbar.

## Kontakt

Fragen oder Anliegen: mail@jankaluza.de

## Änderungen

Aktualisierungen dieser Erklärung werden in dieser Datei committet. Die Privacy-Policy-URL im App-Store-Eintrag verweist immer auf die aktuellste Version im `main`-Branch.
