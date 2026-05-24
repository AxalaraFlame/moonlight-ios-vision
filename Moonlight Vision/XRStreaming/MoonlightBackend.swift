//
//  MoonlightBackend.swift
//  Moonlight Vision
//
//  Adapter that routes flat streaming modes through the existing Moonlight path.
//

import Foundation

@MainActor
struct MoonlightBackend: XRStreamingBackend {
    let id = "moonlight"
    let displayName = "Moonlight / Sunshine"
    let mode: StreamingMode = .uiKitWindow

    func prepareSession(
        for app: TemporaryApp,
        mode: XRStreamingMode,
        viewModel: MainViewModel
    ) async -> StreamConfiguration? {
        guard !mode.usesALVRBackend else { return nil }

        let settings = viewModel.streamSettings
        switch mode {
        case .uiKitWindow:
            settings.renderer = .classic
            settings.realitykitImmersiveMode = false
        case .realityKitWindow:
            settings.renderer = .realitykit
            settings.realitykitImmersiveMode = false
        case .realityKitImmersive:
            settings.renderer = .realitykit
            settings.realitykitImmersiveMode = true
        case .vr:
            break
        }

        settings.save()
        viewModel.activeXRStreamingMode = mode
        return viewModel.stream(app: app)
    }

    func endSession(viewModel: MainViewModel) async {
        viewModel.userDidRequestDisconnect()
    }
}
