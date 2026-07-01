//
//  TVRemote.swift
//  ATVRemote
//
//  Wraps the AndroidTVRemoteControl library (protocol v2) into a
//  SwiftUI-friendly ObservableObject, plus mDNS/Bonjour discovery.
//

import Foundation
import Combine
import Network
@preconcurrency import AndroidTVRemoteControl

/// A TV found on the local network via Bonjour.
struct DiscoveredTV: Identifiable, Hashable {
    let id: String            // Bonjour instance name (unique)
    let name: String          // friendly name to show
    let endpoint: NWEndpoint  // used to resolve the IP on selection
}

@MainActor
final class TVRemote: ObservableObject {

    // UI-observable state
    @Published var status: String = "Idle"
    @Published var isConnected: Bool = false
    @Published var needsCode: Bool = false        // true while the TV shows the 6-char code
    @Published var host: String = ""              // the Android TV IP, e.g. "192.168.1.42"

    // Discovery state
    @Published var discovered: [DiscoveredTV] = []
    @Published var isScanning: Bool = false

    private let pairingManager: PairingManager
    private let remoteManager: RemoteManager
    private var browser: NWBrowser?
    private var didStartPairing = false

    init() {
        // --- Crypto: load OUR self-signed client cert (cert.der bundled in the app) ---
        let cryptoManager = CryptoManager()
        cryptoManager.clientPublicCertificate = {
            guard let url = Bundle.main.url(forResource: "cert", withExtension: "der") else {
                return .Error(.loadCertFromURLError(RemoteError.certNotFound))
            }
            return CertManager().getSecKey(url)
        }

        // --- TLS: load the identity (cert.p12, empty password) for mutual TLS ---
        let tlsManager = TLSManager {
            guard let url = Bundle.main.url(forResource: "cert", withExtension: "p12") else {
                return .Error(.loadCertFromURLError(RemoteError.certNotFound))
            }
            return CertManager().cert(url, "")   // <- empty password, matches how we export the .p12
        }

        // When the TV presents its certificate, hand its public key to the crypto manager.
        tlsManager.secTrustClosure = { secTrust in
            cryptoManager.serverPublicCertificate = {
                if #available(iOS 14.0, *) {
                    guard let key = SecTrustCopyKey(secTrust) else { return .Error(.secTrustCopyKeyError) }
                    return .Result(key)
                } else {
                    guard let key = SecTrustCopyPublicKey(secTrust) else { return .Error(.secTrustCopyKeyError) }
                    return .Result(key)
                }
            }
        }

        pairingManager = PairingManager(tlsManager, cryptoManager, DefaultLogger())
        remoteManager  = RemoteManager(tlsManager,
                                       CommandNetwork.DeviceInfo("client", "iPhone", "1.0.0", "ATVRemote", "1"),
                                       DefaultLogger())
    }

    // MARK: - Discovery

    /// Scan the local network for Android TVs advertising the remote-v2 service.
    func startDiscovery() {
        stopDiscovery()
        discovered = []
        isScanning = true

        let params = NWParameters()
        let b = NWBrowser(for: .bonjour(type: "_androidtvremote2._tcp", domain: "local."), using: params)

        b.browseResultsChangedHandler = { results, _ in
            Task { @MainActor in
                self.discovered = results.compactMap { result in
                    if case let .service(name, _, _, _) = result.endpoint {
                        return DiscoveredTV(id: name, name: name, endpoint: result.endpoint)
                    }
                    return nil
                }
            }
        }
        b.stateUpdateHandler = { state in
            if case .failed = state {
                Task { @MainActor in self.isScanning = false }
            }
        }

        browser = b
        b.start(queue: .main)
    }

    func stopDiscovery() {
        browser?.cancel()
        browser = nil
        isScanning = false
    }

    /// Pick a discovered TV: resolve its IP, then connect.
    func select(_ device: DiscoveredTV) {
        status = "Resolving \(device.name)…"
        resolveIP(device.endpoint) { ip in
            Task { @MainActor in
                guard let ip else { self.status = "Could not resolve \(device.name)"; return }
                self.host = ip
                self.connect()
            }
        }
    }

    /// Resolve a Bonjour endpoint to an IP string by briefly opening a connection.
    /// We force IPv4: Bonjour often hands back a link-local IPv6 (fe80::…) address,
    /// which isn't routable without its zone id and tends to fail with "Network is down".
    private func resolveIP(_ endpoint: NWEndpoint, completion: @escaping @Sendable (String?) -> Void) {
        let params = NWParameters.tcp
        if let ip = params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ip.version = .v4
        }
        let conn = NWConnection(to: endpoint, using: params)
        conn.stateUpdateHandler = { state in
            switch state {
            case .ready:
                var resolved: String?
                if case let .hostPort(host, _)? = conn.currentPath?.remoteEndpoint {
                    switch host {
                    case .ipv4(let a): resolved = "\(a)".components(separatedBy: "%").first
                    case .ipv6(let a): resolved = "\(a)"   // keep the zone id if it ever is IPv6
                    case .name(let n, _): resolved = n
                    @unknown default: break
                    }
                }
                conn.cancel()
                completion(resolved)
            case .failed:
                conn.cancel()
                completion(nil)
            default:
                break
            }
        }
        conn.start(queue: .global())
    }

    // MARK: - Connection

    /// Try to connect. If the device isn't paired yet, the library reports
    /// `connectionWaitingError`, and we kick off the pairing handshake.
    func connect() {
        let target = host.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { status = "Enter the TV IP first"; return }
        didStartPairing = false          // fresh user-initiated attempt
        establishRemote(target)
    }

    private func establishRemote(_ target: String) {
        // The library calls this back from its own network queue -> hop to main.
        remoteManager.stateChanged = { state in
            Task { @MainActor in self.handleRemote(state, host: target) }
        }
        remoteManager.connect(target)
    }

    private func handleRemote(_ state: RemoteManager.RemoteState, host target: String) {
        print("ATV remote ▸ \(state)")   // full state incl. exact error -> Xcode console
        status = state.label
        switch state {
        case .connected, .paired:
            isConnected = true
            stopDiscovery()
        case .error:
            // Not paired yet: an unknown client cert is rejected either as a
            // "connection waiting" state or a TLS certificate error (-9825).
            // Either way, run the pairing handshake once to register our cert.
            if !didStartPairing {
                didStartPairing = true
                startPairing(host: target)
            }
        default:
            break
        }
    }

    private func startPairing(host target: String) {
        pairingManager.stateChanged = { state in
            Task { @MainActor in self.handlePairing(state, host: target) }
        }
        pairingManager.connect(target, "client", "iPhone")
    }

    private func handlePairing(_ state: PairingManager.PairingState, host target: String) {
        print("ATV pairing ▸ \(state)")   // full state incl. exact error -> Xcode console
        status = "Pairing: " + state.label
        switch state {
        case .waitingCode:
            needsCode = true                 // show the code field in the UI
        case .successPaired:
            needsCode = false
            establishRemote(target)          // reconnect now that we're trusted
        default:
            break
        }
    }

    /// Send the 6-character code (digits 0-9, letters A-F) shown on the TV.
    func sendCode(_ code: String) {
        pairingManager.sendSecret(code.trimmingCharacters(in: .whitespaces).uppercased())
    }

    // MARK: - Commands

    func press(_ key: Key) {
        remoteManager.send(KeyPress(key))
    }

    func openApp(_ url: String) {
        remoteManager.send(DeepLink(url))
    }
}

enum RemoteError: Error { case certNotFound }

// Small label helpers so the UI can show readable state.
private extension RemoteManager.RemoteState {
    var label: String {
        switch self {
        case .idle: return "Idle"
        case .connectionSetUp: return "Setting up…"
        case .connectionPrepairing: return "Preparing…"
        case .connected: return "Connected"
        case .fisrtConfigMessageReceived(let i): return "Got config: \(i.model)"
        case .firstConfigSent: return "Config sent…"
        case .secondConfigSent: return "Almost there…"
        case .paired(let app): return "Ready" + (app.map { " · \($0)" } ?? "")
        case .error: return "Not connected"
        }
    }
}

private extension PairingManager.PairingState {
    var label: String {
        switch self {
        case .idle: return "idle"
        case .extractTLSparams: return "TLS params"
        case .connectionSetUp: return "set up"
        case .connectionPrepairing: return "preparing"
        case .connected: return "connected"
        case .pairingRequestSent: return "request sent"
        case .pairingResponseSuccess: return "request ok"
        case .optionRequestSent: return "option sent"
        case .optionResponseSuccess: return "option ok"
        case .confirmationRequestSent: return "confirm sent"
        case .confirmationResponseSuccess: return "confirm ok"
        case .waitingCode: return "enter the code on screen"
        case .secretSent: return "code sent…"
        case .successPaired: return "paired!"
        case .error: return "error"
        }
    }
}
