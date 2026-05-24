//
//  XRStreamingBackend.swift
//  Moonlight Vision
//
//  Pluggable XR streaming backend contracts.
//

import Foundation

enum StreamingMode: String, CaseIterable, Identifiable {
    case uiKitWindow
    case realityKitWindow
    case realityKitImmersive
    case vr

    var id: String { rawValue }

    var titleLocalizationKey: String {
        switch self {
        case .uiKitWindow: return "stream_mode_uikit"
        case .realityKitWindow: return "stream_mode_realitykit_window"
        case .realityKitImmersive: return "stream_mode_realitykit_immersive"
        case .vr: return "stream_mode_vr"
        }
    }

    var subtitleLocalizationKey: String {
        switch self {
        case .uiKitWindow: return "stream_mode_uikit_desc"
        case .realityKitWindow: return "stream_mode_realitykit_window_desc"
        case .realityKitImmersive: return "stream_mode_realitykit_immersive_desc"
        case .vr: return "stream_mode_vr_desc"
        }
    }

    var iconName: String {
        switch self {
        case .uiKitWindow: return "rectangle.portrait"
        case .realityKitWindow: return "square.stack.3d.up.fill"
        case .realityKitImmersive: return "viewfinder"
        case .vr: return "visionpro"
        }
    }

    var destination: XRStreamingDestination {
        switch self {
        case .uiKitWindow:
            return .window(id: "classicStreamingWindow")
        case .realityKitWindow:
            return .window(id: "realitykitStreamingWindow")
        case .realityKitImmersive:
            return .immersiveSpace(id: "realitykitImmersiveSpace")
        case .vr:
            return .immersiveSpace(id: "ALVRImmersiveSpace")
        }
    }

    var usesALVRBackend: Bool {
        self == .vr
    }

    var usesCloudXRBackend: Bool {
        usesALVRBackend
    }
}

typealias XRStreamingMode = StreamingMode

enum XRStreamingDestination {
    case window(id: String)
    case immersiveSpace(id: String)
}

@MainActor
protocol StreamingBackend {
    var id: String { get }
    var displayName: String { get }
    var mode: StreamingMode { get }

    func connect() async
    func disconnect() async

    func prepareSession(
        for app: TemporaryApp,
        mode: StreamingMode,
        viewModel: MainViewModel
    ) async -> StreamConfiguration?

    func endSession(viewModel: MainViewModel) async
}

typealias XRStreamingBackend = StreamingBackend

extension StreamingBackend {
    func connect() async {}
    func disconnect() async {}
}
