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
    @Published private(set) var portDescription = ""
    @Published private(set) var txtRecordDescription = ""
    @Published private(set) var lastError: String?
    @Published private(set) var isBroadcasting = false

    private var listener: NWListener?

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
        lastError = nil
        isBroadcasting = false
        serviceName = "ALVR Apple Vision Pro"
        self.serviceType = serviceType
        self.deviceId = deviceId
        self.protocolId = protocolId
        portDescription = "System assigned"

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
        lastError = nil
        isBroadcasting = false
        portDescription = ""
    }

    private func handleListenerState(_ listenerState: NWListener.State) {
        switch listenerState {
        case .setup:
            state = .starting
            isBroadcasting = false
        case .waiting(let error):
            fail(error.localizedDescription)
        case .ready:
            state = .ready
            isBroadcasting = true
            portDescription = listener?.port.map(String.init(describing:)) ?? "System assigned"
        case .failed(let error):
            fail(error.localizedDescription)
        case .cancelled:
            listener = nil
            state = .stopped
            isBroadcasting = false
            portDescription = ""
        @unknown default:
            fail("Unknown NWListener state")
        }
    }

    private func fail(_ message: String) {
        listener?.cancel()
        listener = nil
        state = .failed(message)
        lastError = message
        isBroadcasting = false
        portDescription = ""
    }
}
