//
//  CloudXRBackend.swift
//  Moonlight Vision
//
//  Placeholder CloudXR backend and foveated streaming session.
//

import Combine
import Foundation

struct FoveatedStreamingConfiguration: Equatable {
    var innerRadius: Float = 0.35
    var middleRadius: Float = 0.65
    var edgeScale: Float = 0.5
    var targetFrameRate: Int32
}

struct CloudXRSessionDescriptor: Equatable {
    var hostAddress: String
    var appID: String
    var appName: String
    var width: Int32
    var height: Int32
    var foveation: FoveatedStreamingConfiguration
}

@MainActor
final class CloudXRFoveatedStreamingSession: ObservableObject {
    enum State: Equatable {
        case idle
        case connecting
        case streaming
        case stopped
        case failed(String)
    }

    let descriptor: CloudXRSessionDescriptor

    @Published private(set) var state: State = .idle

    init(descriptor: CloudXRSessionDescriptor) {
        self.descriptor = descriptor
    }

    func start() async {
        guard state == .idle || state == .stopped else { return }
        state = .connecting

        // Placeholder for CloudXR client connection, eye texture setup, and foveated transport.
        try? await Task.sleep(nanoseconds: 250_000_000)
        guard !Task.isCancelled else { return }
        state = .streaming
    }

    func stop() {
        state = .stopped
    }
}

@MainActor
final class CloudXRSessionStore: ObservableObject {
    static let shared = CloudXRSessionStore()

    @Published var activeSession: CloudXRFoveatedStreamingSession?

    private init() {}
}

@MainActor
struct CloudXRBackend: XRStreamingBackend {
    let id = "cloudxr"
    let displayName = "CloudXR"
    let mode: StreamingMode = .vr

    func prepareSession(
        for app: TemporaryApp,
        mode: XRStreamingMode,
        viewModel: MainViewModel
    ) async -> StreamConfiguration? {
        guard mode == .vr else { return nil }

        viewModel.prepareForNewStream()

        guard let host = app.host() else {
            print("CloudXRBackend - ERROR: App \(app.name ?? "Unknown") has no associated host.")
            return nil
        }

        guard let hostAddress = host.activeAddress ?? host.address else {
            print("CloudXRBackend - ERROR: Host \(host.name) has no valid address.")
            return nil
        }

        let config = StreamConfiguration()
        config.sessionUUID = viewModel.activeSessionToken
        config.host = hostAddress
        config.httpsPort = host.httpsPort
        config.appID = app.id
        config.appName = app.name
        config.serverCert = host.serverCert
        config.frameRate = viewModel.streamSettings.framerate
        config.height = viewModel.streamSettings.height
        config.width = viewModel.streamSettings.width
        config.bitRate = viewModel.streamSettings.bitrate

        let descriptor = CloudXRSessionDescriptor(
            hostAddress: hostAddress,
            appID: app.id ?? "",
            appName: app.name ?? "VR",
            width: config.width,
            height: config.height,
            foveation: FoveatedStreamingConfiguration(targetFrameRate: config.frameRate)
        )

        CloudXRSessionStore.shared.activeSession = CloudXRFoveatedStreamingSession(descriptor: descriptor)

        viewModel.currentStreamConfig = config
        viewModel.savedStreamConfigForResume = config
        viewModel.activelyStreaming = true
        viewModel.streamState = .starting
        viewModel.currentlyStreamingAppId = app.id ?? app.name
        viewModel.activeXRStreamingMode = .vr

        return config
    }

    func endSession(viewModel: MainViewModel) async {
        CloudXRSessionStore.shared.activeSession?.stop()
        CloudXRSessionStore.shared.activeSession = nil
        viewModel.forceResetStreamLifecycleIfNeeded()
        viewModel.activeXRStreamingMode = nil
        viewModel.savedStreamConfigForResume = nil
    }
}
