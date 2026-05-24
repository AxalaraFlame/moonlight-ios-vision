//
//  XRStreamingTypes.swift
//  Moonlight Vision
//
//  Convenience wrappers for selecting flat or VR streaming backends.
//

import Foundation
import SwiftUI

@MainActor
struct FlatStreaming {
    var backend = MoonlightBackend()

    func prepare(
        app: TemporaryApp,
        mode: XRStreamingMode,
        viewModel: MainViewModel
    ) async -> StreamConfiguration? {
        await backend.prepareSession(for: app, mode: mode, viewModel: viewModel)
    }
}

@MainActor
struct VRStreaming {
    var backend = ALVRBackend()

    func prepare(
        app: TemporaryApp,
        viewModel: MainViewModel
    ) async -> StreamConfiguration? {
        await backend.prepareSession(for: app, mode: .vr, viewModel: viewModel)
    }
}
