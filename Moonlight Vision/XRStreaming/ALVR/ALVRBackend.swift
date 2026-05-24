//
//  ALVRBackend.swift
//  Moonlight Vision
//
//  Pluggable backend placeholder for ALVR VR streaming.
//

import Foundation

@MainActor
struct ALVRBackend: StreamingBackend {
    let id = "alvr"
    let displayName = "ALVR / SteamVR"
    let mode: StreamingMode = .vr

    func connect() async {
        ALVRClientCoreBridge.shared.initializePlaceholder()
    }

    func disconnect() async {
        await ALVRSessionManager.shared.disconnect()
    }

    func prepareSession(
        for app: TemporaryApp,
        mode: StreamingMode,
        viewModel: MainViewModel
    ) async -> StreamConfiguration? {
        guard mode == .vr else { return nil }

        ALVRClientCoreBridge.shared.initializePlaceholder()
        viewModel.prepareForNewStream()
        viewModel.activeXRStreamingMode = .vr

        let config = StreamConfiguration()
        config.sessionUUID = viewModel.activeSessionToken
        config.appID = app.id
        config.appName = app.name
        config.frameRate = viewModel.streamSettings.framerate
        config.height = viewModel.streamSettings.height
        config.width = viewModel.streamSettings.width
        config.bitRate = viewModel.streamSettings.bitrate

        // TODO: Migrate ALVR connection, decoder, renderer, pose input, and controller input from alvr-org/alvr-visionos.
        return config
    }

    func endSession(viewModel: MainViewModel) async {
        await ALVRSessionManager.shared.disconnect(viewModel: viewModel)
    }
}
