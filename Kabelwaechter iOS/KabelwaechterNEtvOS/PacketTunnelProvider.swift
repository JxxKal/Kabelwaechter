import NetworkExtension
import os.log
import KabelwaechterCore
import WireGuardKit

/// Packet-Tunnel-Provider für die tvOS Network Extension.
///
/// Lifecycle:
/// 1. App ruft `NETunnelProviderManager.connection.startVPNTunnel()` → System
///    spawnt diese NE.
/// 2. `startTunnel(options:completionHandler:)` wird gerufen mit unserem
///    `providerConfiguration["wgQuickConfig"]: String` (vom `TunnelManager`
///    serialisiert).
/// 3. Wir parsen via Core, übersetzen zu WireGuardKit-Typen, starten den
///    `WireGuardAdapter`.
class PacketTunnelProvider: NEPacketTunnelProvider {

    private lazy var adapter: WireGuardAdapter = {
        WireGuardAdapter(with: self) { logLevel, message in
            NSLog("[KabelwaechterNE] [%@] %@", String(describing: logLevel), message)
        }
    }()

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        NSLog("[KabelwaechterNE] startTunnel — Bundle-ID: %@", KabelwaechterConstants.BundleIdentifiers.tvOSNetworkExtension)

        guard let proto = self.protocolConfiguration as? NETunnelProviderProtocol,
              let providerConfig = proto.providerConfiguration,
              let wgQuickString = providerConfig["wgQuickConfig"] as? String else {
            NSLog("[KabelwaechterNE] kein wgQuickConfig in providerConfiguration")
            completionHandler(StartError.missingProviderConfiguration)
            return
        }

        let coreConfig: KabelwaechterCore.TunnelConfiguration
        do {
            coreConfig = try KabelwaechterCore.TunnelConfiguration(fromWgQuickConfig: wgQuickString)
        } catch {
            NSLog("[KabelwaechterNE] wgQuick-Parse fehlgeschlagen: %@", String(describing: error))
            completionHandler(StartError.invalidWgQuickConfig(underlying: error))
            return
        }

        let wgConfig: WireGuardKit.TunnelConfiguration
        do {
            wgConfig = try CoreToWireGuardKit.adapt(coreConfig)
        } catch {
            NSLog("[KabelwaechterNE] Core→WireGuardKit-Mapping fehlgeschlagen: %@", String(describing: error))
            completionHandler(StartError.invalidConfiguration(underlying: error))
            return
        }

        adapter.start(tunnelConfiguration: wgConfig) { error in
            if let error {
                NSLog("[KabelwaechterNE] WireGuardAdapter.start Fehler: %@", String(describing: error))
                completionHandler(error)
            } else {
                NSLog("[KabelwaechterNE] Tunnel gestartet")
                completionHandler(nil)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        NSLog("[KabelwaechterNE] stopTunnel — Grund: %ld", reason.rawValue)
        adapter.stop { error in
            if let error {
                NSLog("[KabelwaechterNE] WireGuardAdapter.stop Fehler: %@", String(describing: error))
            }
            completionHandler()
        }
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Phase 3 nutzt diesen Pfad nicht — Status-Updates kommen via
        // NEVPNStatusDidChange-Notification automatisch.
        completionHandler?(nil)
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    override func wake() {}

    // MARK: - Errors

    enum StartError: Error {
        case missingProviderConfiguration
        case invalidWgQuickConfig(underlying: Error)
        case invalidConfiguration(underlying: Error)
    }
}
