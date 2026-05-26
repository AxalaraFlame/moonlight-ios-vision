//
//  ALVRMdnsBroadcaster.swift
//  Moonlight Vision
//
//  Independent Bonjour broadcaster for the placeholder ALVR client path.
//

import Foundation
import Network

@MainActor
final class ALVRMdnsBroadcaster: ObservableObject {
    enum State: Equatable {
        case idle
        case starting
        case ready
        case failed(String)
        case stopped

        var description: String {
            switch self {
            case .idle:
                return "Idle"
            case .starting:
                return "Starting"
            case .ready:
                return "Ready"
            case .failed(let message):
                return "Failed: \(message)"
            case .stopped:
                return "Stopped"
            }
        }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var serviceName = ""
    @Published private(set) var serviceType = ""
    @Published private(set) var deviceId = ""
    @Published private(set) var protocolId = ""
    @Published private(set) var activeHostname = ""
    @Published private(set) var portDescription = ""
    @Published private(set) var activePort: UInt16?
    @Published private(set) var txtRecordDescription = ""
    @Published private(set) var lastError: String?
    @Published private(set) var isBroadcasting = false
    @Published private(set) var listenerStateDescription = "Idle"
    @Published private(set) var listenerStartTimeDescription = ""
    @Published private(set) var listenerRestartCount = 0
    @Published private(set) var localIPv4Candidates: [String] = []
    @Published private(set) var ignoredIPv4Candidates: [String] = []
    @Published private(set) var recommendedManualConnectionAddress: String?
    @Published private(set) var listenerPortChangedWarning: String?

    var listenerReady: Bool {
        isBroadcasting
    }

    private var listener: NWListener?
    private var listenerStartCount = 0
    private var lastReadyPort: UInt16?

    init() {
        print("[ALVR MdnsBroadcaster] init")
    }

    deinit {
        print("[ALVR MdnsBroadcaster] deinit")
    }

    func start(clientInfo: ALVRClientInfoResult) async {
        guard listener == nil else {
            return
        }

        guard let serviceType = clientInfo.serviceType, !serviceType.isEmpty else {
            fail("ALVR service type is unavailable. Load ALVR Client Info first.")
            return
        }

        guard let deviceId = clientInfo.deviceId, !deviceId.isEmpty else {
            fail("ALVR device ID is unavailable. Load ALVR Client Info first.")
            return
        }

        guard let protocolId = clientInfo.protocolId, !protocolId.isEmpty else {
            fail("ALVR protocol ID is unavailable. Load ALVR Client Info first.")
            return
        }

        state = .starting
        listenerStateDescription = state.description
        lastError = nil
        isBroadcasting = false
        serviceName = "ALVR Apple Vision Pro"
        self.serviceType = serviceType
        self.deviceId = deviceId
        self.protocolId = protocolId
        activeHostname = clientInfo.deviceId ?? clientInfo.rawHostname.map { "\($0).alvr" } ?? ""
        let classifiedAddresses = Self.classifyIPv4Addresses(clientInfo.localIPv4Addresses)
        localIPv4Candidates = classifiedAddresses.usable
        ignoredIPv4Candidates = classifiedAddresses.ignored
        portDescription = "System assigned"
        activePort = nil
        recommendedManualConnectionAddress = nil
        listenerStartCount += 1
        listenerRestartCount = max(0, listenerStartCount - 1)
        listenerStartTimeDescription = Self.listenerDateFormatter.string(from: Date())

        let txtRecordValues = [
            "protocol": protocolId,
            "device_id": deviceId,
            "salt": String(Date().timeIntervalSinceReferenceDate)
        ]
        txtRecordDescription = txtRecordValues
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")

        do {
            let listener = try NWListener(using: .tcp)
            listener.service = NWListener.Service(
                name: serviceName,
                type: serviceType,
                txtRecord: NWTXTRecord(txtRecordValues)
            )
            listener.newConnectionHandler = { connection in
                connection.cancel()
            }
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    self?.handleListenerState(state)
                }
            }
            self.listener = listener
            listener.start(queue: DispatchQueue.global(qos: .background))
        } catch {
            fail(error.localizedDescription)
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        state = .stopped
        listenerStateDescription = state.description
        lastError = nil
        isBroadcasting = false
        portDescription = ""
        activePort = nil
        recommendedManualConnectionAddress = nil
    }

    private func handleListenerState(_ listenerState: NWListener.State) {
        switch listenerState {
        case .setup:
            state = .starting
            listenerStateDescription = "Setup"
            isBroadcasting = false
        case .waiting(let error):
            listenerStateDescription = "Waiting: \(error.localizedDescription)"
            fail(error.localizedDescription)
        case .ready:
            state = .ready
            listenerStateDescription = state.description
            isBroadcasting = true
            if let port = listener?.port {
                let portValue = port.rawValue
                activePort = portValue
                portDescription = String(portValue)
                if let lastReadyPort, lastReadyPort != portValue {
                    listenerPortChangedWarning = "mDNS listener port changed. Restart ALVR discovery on the PC or manually add the new IP:port."
                }
                lastReadyPort = portValue
            } else {
                activePort = nil
                portDescription = "System assigned"
            }
            updateRecommendedManualConnectionAddress()
        case .failed(let error):
            listenerStateDescription = "Failed: \(error.localizedDescription)"
            fail(error.localizedDescription)
        case .cancelled:
            listener = nil
            state = .stopped
            listenerStateDescription = state.description
            isBroadcasting = false
            portDescription = ""
            activePort = nil
            recommendedManualConnectionAddress = nil
        @unknown default:
            listenerStateDescription = "Unknown"
            fail("Unknown NWListener state")
        }
    }

    private func fail(_ message: String) {
        listener?.cancel()
        listener = nil
        state = .failed(message)
        listenerStateDescription = state.description
        lastError = message
        isBroadcasting = false
        portDescription = ""
        activePort = nil
        recommendedManualConnectionAddress = nil
    }

    private func updateRecommendedManualConnectionAddress() {
        guard let activePort else {
            recommendedManualConnectionAddress = nil
            return
        }

        guard let address = Self.preferredManualAddress(from: localIPv4Candidates) else {
            recommendedManualConnectionAddress = nil
            return
        }

        recommendedManualConnectionAddress = "\(address):\(activePort)"
    }

    private static func classifyIPv4Addresses(_ addresses: [String]) -> (usable: [String], ignored: [String]) {
        var usable: [String] = []
        var ignored: [String] = []

        for address in addresses {
            let octets = address.split(separator: ".").compactMap { Int($0) }
            guard octets.count == 4 else {
                ignored.append(address)
                continue
            }

            let isLoopback = octets[0] == 127
            let isLinkLocal = octets[0] == 169 && octets[1] == 254
            let isBenchmarkNetwork = octets[0] == 198 && (octets[1] == 18 || octets[1] == 19)

            if isLoopback || isLinkLocal || isBenchmarkNetwork {
                ignored.append(address)
            } else {
                usable.append(address)
            }
        }

        return (usable, ignored)
    }

    private static func preferredManualAddress(from addresses: [String]) -> String? {
        addresses.first(where: { $0.hasPrefix("10.") })
            ?? addresses.first(where: { $0.hasPrefix("192.168.") })
            ?? addresses.first(where: { address in
                let octets = address.split(separator: ".").compactMap { Int($0) }
                guard octets.count == 4 else { return false }
                return octets[0] == 172 && (16...31).contains(octets[1])
            })
            ?? addresses.first
    }

    private static let listenerDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
}
