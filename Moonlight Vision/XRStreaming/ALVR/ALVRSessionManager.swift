//
//  ALVRSessionManager.swift
//  Moonlight Vision
//
//  Placeholder ALVR session state for future native VR streaming.
//

import Combine
import Foundation

@MainActor
final class ALVRSessionManager: ObservableObject {
    enum State: Equatable, CustomStringConvertible {
        case idle
        case discovering
        case pairing
        case connecting
        case connected
        case streaming
        case disconnecting
        case failed(String)

        var description: String {
            switch self {
            case .idle:
                return "idle"
            case .discovering:
                return "discovering"
            case .pairing:
                return "pairing"
            case .connecting:
                return "connecting"
            case .connected:
                return "connected"
            case .streaming:
                return "streaming"
            case .disconnecting:
                return "disconnecting"
            case .failed(let message):
                return "failed: \(message)"
            }
        }
    }

    static let shared = ALVRSessionManager()

    @Published private(set) var state: State = .idle
    @Published var hostAddress: String = ""
    @Published private(set) var appName: String = ""
    @Published private(set) var errorMessage: String?

    var isConnected: Bool {
        switch state {
        case .connected, .streaming:
            return true
        case .idle, .discovering, .pairing, .connecting, .disconnecting, .failed:
            return false
        }
    }

    var pcAddress: String { hostAddress }
    var lastError: String? { errorMessage }

    private init() {}

    func beginDiscovery() {
        state = .discovering
        errorMessage = nil
        // TODO: Migrate ALVR server discovery from alvr-org/alvr-visionos.
    }

    func beginPairing() {
        state = .pairing
        errorMessage = nil
        // TODO: Migrate ALVR pairing and trust handshake from alvr-org/alvr-visionos.
    }

    func connect(hostAddress: String) async {
        let trimmedAddress = hostAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            fail("Enter a PC IP address.")
            return
        }

        state = .connecting
        errorMessage = nil
        self.hostAddress = trimmedAddress

        // TODO: alvr_initialize.
        // TODO: alvr_resume.
        // TODO: alvr_poll_event.
        // TODO: alvr_send_tracking_and_face_data.
        // TODO: alvr_send_views_config.
        // TODO: decoder callback.
        // TODO: STREAMING_STARTED / STREAMING_STOPPED / DECODER_CONFIG event handling.
        ALVRClientCoreBridge.shared.initializePlaceholder()
        ALVRClientCoreBridge.shared.resumePlaceholder()

        try? await Task.sleep(nanoseconds: 250_000_000)
        guard !Task.isCancelled else { return }

        state = .connected
    }

    func connect(to pcAddress: String, app: TemporaryApp?, viewModel: MainViewModel) async -> Bool {
        appName = app?.name ?? "VR"

        await connect(hostAddress: pcAddress)
        guard isConnected else { return false }

        viewModel.activeXRStreamingMode = .vr
        viewModel.activelyStreaming = true
        viewModel.streamState = .running
        viewModel.savedStreamConfigForResume = nil
        viewModel.currentlyStreamingAppId = app?.id ?? app?.name

        state = .connected
        return true
    }

    func disconnect() async {
        guard state != .idle else { return }
        state = .disconnecting
        ALVRClientCoreBridge.shared.stopPlaceholder()
        try? await Task.sleep(nanoseconds: 100_000_000)
        guard !Task.isCancelled else { return }
        state = .idle
        hostAddress = ""
        appName = ""
        errorMessage = nil
    }

    func disconnect(viewModel: MainViewModel) async {
        await disconnect()
        viewModel.forceResetStreamLifecycleIfNeeded()
        viewModel.activeXRStreamingMode = nil
    }

    func startPlaceholderStreaming() async {
        guard state == .connected || state == .streaming else { return }
        state = .streaming
        ALVRRendererBridge.shared.startPlaceholderRenderer()
        ALVRInputBridge.shared.startPlaceholderHeadPoseTracking()
    }

    func stopPlaceholderStreaming() async {
        guard state == .streaming else { return }
        ALVRRendererBridge.shared.stopPlaceholderRenderer()
        ALVRInputBridge.shared.stopPlaceholderHeadPoseTracking()
        state = .connected
    }

    private func fail(_ message: String) {
        errorMessage = message
        state = .failed(message)
    }
}
