# Go-Bridge als Run-Script-Phase statt Legacy-External-Build-Target

Die WireGuard-Go-Bridge (`libwg-go.a`) wurde bisher von je einem
**Legacy-/External-Build-Target** (`WireguardGoBridge{tvOS,iOS}`) gebaut, das
`make` im SPM-Checkout aufrief. Das funktionierte für `build`, **scheiterte
aber beim `archive`** (TestFlight/App Store). Ersetzt durch eine
**Run-Script-Build-Phase** in jeder NE.

## Zwei Archive-Bugs, die das Legacy-Target hatte
1. **Arbeitsverzeichnis weg.** Das Target nutzte
   `$(BUILD_DIR)/../../SourcePackages/checkouts/…`. Bei `archive` liegt
   `BUILD_DIR` tiefer (`…/ArchiveIntermediates/<scheme>/…`), der relative
   `../../`-Pfad zeigt ins Leere → „unable to spawn process '/usr/bin/env'
   (No such file or directory)" (das CWD existiert nicht). Ein einzelner
   relativer Pfad kann `build` und `archive` nicht beide treffen.
2. **Leerzeichen im Pfad.** Das tvOS-Scheme heißt „Kabelwaechter tvOS" (mit
   Space) → `CONFIGURATION_TEMP_DIR` enthält beim Archive ein Leerzeichen.
   Das WireGuard-Makefile nutzt den Pfad im `.prepared`-Target unquotiert →
   `make` kann keine Spaces in Targets → „touch: …: No such file or directory".

## Lösung (Run-Script-Phase, erste Phase der NE)
```sh
SRC="${BUILD_DIR%/Build/*}/SourcePackages/checkouts/wireguard-apple-tvos/Sources/WireGuardKitGo"
OUT="${BUILD_DIR%/Build/*}/kwgobridge/${PLATFORM_NAME}-${CONFIGURATION}"   # space-frei
cd "$SRC"
make [PLATFORM_NAME=iphoneos] CONFIGURATION_BUILD_DIR="$OUT/out" CONFIGURATION_TEMP_DIR="$OUT/tmp"
cp "$OUT/out/libwg-go.a" "$BUILT_PRODUCTS_DIR/libwg-go.a"
```
- `${BUILD_DIR%/Build/*}` schält den DerivedData-Root (space-frei) heraus —
  robust für `build` **und** `archive`.
- `make` baut in ein **space-freies** Verzeichnis (umgeht den Makefile-Space-
  Bug); `libwg-go.a` wird per Shell (space-tolerant) nach `BUILT_PRODUCTS_DIR`
  kopiert, wo der Linker es via `-lwg-go` findet.
- tvOS-NE übergibt `PLATFORM_NAME=iphoneos` (SDK-Trick); iOS-NE nicht (nativ).
- `ENABLE_USER_SCRIPT_SANDBOXING = NO` für die Phase.

**Folgen:** Beide Apps archivieren sauber (NE eingebettet, signiert). Die alten
`WireguardGoBridge{iOS,tvOS}`-Targets sind ungenutzt und können entfernt werden.
