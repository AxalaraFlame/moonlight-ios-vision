//
//  ALVRClientCoreBridge.swift
//  Moonlight Vision
//
//  Bridge skeleton for the generated ALVRClientCore.xcframework.
//

import Foundation

#if canImport(ALVRClientCore)
import ALVRClientCore
#endif

struct SymbolSmokeResult {
    let success: Bool
    let messages: [String]
    let pathId: UInt64?
    let errorDescription: String?
}

struct LifecycleSmokeResult {
    let success: Bool
    let messages: [String]
    let didInitialize: Bool
    let didPollEvent: Bool
    let hasEvent: Bool
    let eventTagRawValue: UInt32?
    let didDestroy: Bool
    let errorDescription: String?
}

@MainActor
final class ALVRClientCoreBridge {
    static let shared = ALVRClientCoreBridge()

    private var isLifecycleSmokeTestRunning = false

    var isFrameworkAvailable: Bool {
        #if canImport(ALVRClientCore)
        true
        #else
        false
        #endif
    }

    var frameworkStatusDescription: String {
        #if canImport(ALVRClientCore)
        "ALVRClientCore import: available"
        #else
        "ALVRClientCore import: unavailable"
        #endif
    }

    private init() {}

    func runSymbolSmokeTest() -> SymbolSmokeResult {
        #if canImport(ALVRClientCore)
        alvr_initialize_logging()

        let pathId = "/user/head".withCString { pathPointer in
            alvr_path_string_to_id(pathPointer)
        }

        "Moonlight Vision ALVR symbol smoke test".withCString { messagePointer in
            alvr_log(AlvrLogLevel(ALVR_LOG_LEVEL_INFO.rawValue), messagePointer)
        }

        return SymbolSmokeResult(
            success: true,
            messages: [
                "ALVRClientCore import available",
                "Called alvr_initialize_logging()",
                "Called alvr_path_string_to_id(\"/user/head\")",
                "Called alvr_log(ALVR_LOG_LEVEL_INFO, ...)"
            ],
            pathId: pathId,
            errorDescription: nil
        )
        #else
        return SymbolSmokeResult(
            success: false,
            messages: ["ALVRClientCore import unavailable"],
            pathId: nil,
            errorDescription: "ALVRClientCore is not available to this target."
        )
        #endif
    }

    func runLifecycleSmokeTest() -> LifecycleSmokeResult {
        guard !isLifecycleSmokeTestRunning else {
            return LifecycleSmokeResult(
                success: false,
                messages: ["Lifecycle smoke test already running"],
                didInitialize: false,
                didPollEvent: false,
                hasEvent: false,
                eventTagRawValue: nil,
                didDestroy: false,
                errorDescription: "Lifecycle smoke test already running."
            )
        }

        isLifecycleSmokeTestRunning = true
        defer { isLifecycleSmokeTestRunning = false }

        #if canImport(ALVRClientCore)
        var messages = ["ALVRClientCore import available"]
        var didInitialize = false
        var didPollEvent = false
        var hasEvent = false
        var eventTagRawValue: UInt32?
        var didDestroy = false

        defer {
            if didInitialize && !didDestroy {
                alvr_destroy()
            }
        }

        let refreshRates: [Float] = [90]
        refreshRates.withUnsafeBufferPointer { refreshRatesPointer in
            let capabilities = AlvrClientCapabilities(
                default_view_width: 1920,
                default_view_height: 1920,
                refresh_rates: refreshRatesPointer.baseAddress,
                refresh_rates_count: 1,
                foveated_encoding: false,
                encoder_high_profile: true,
                encoder_10_bits: false,
                encoder_av1: false,
                prefer_10bit: false,
                prefer_full_range: true,
                preferred_encoding_gamma: 1.0,
                prefer_hdr: false
            )

            alvr_initialize(capabilities)
            didInitialize = true
            messages.append("Called alvr_initialize(capabilities)")
        }

        alvr_initialize_logging()
        messages.append("Called alvr_initialize_logging()")

        var event = AlvrEvent()
        hasEvent = alvr_poll_event(&event)
        didPollEvent = true
        messages.append("Called alvr_poll_event(&event) once")

        if hasEvent {
            eventTagRawValue = UInt32(event.tag)
            messages.append("alvr_poll_event returned an event with tag \(eventTagRawValue!)")
        } else {
            messages.append("alvr_poll_event returned no event")
        }

        alvr_destroy()
        didDestroy = true
        messages.append("Called alvr_destroy()")

        return LifecycleSmokeResult(
            success: true,
            messages: messages,
            didInitialize: didInitialize,
            didPollEvent: didPollEvent,
            hasEvent: hasEvent,
            eventTagRawValue: eventTagRawValue,
            didDestroy: didDestroy,
            errorDescription: nil
        )
        #else
        return LifecycleSmokeResult(
            success: false,
            messages: ["ALVRClientCore import unavailable"],
            didInitialize: false,
            didPollEvent: false,
            hasEvent: false,
            eventTagRawValue: nil,
            didDestroy: false,
            errorDescription: "ALVRClientCore is not available to this target."
        )
        #endif
    }

    func initializePlaceholder() {
        // TODO: Bridge alvr_initialize once the framework is linked and symbols are verified.
    }

    func resumePlaceholder() {
        // TODO: Bridge alvr_resume once lifecycle ownership is isolated from the upstream app.
    }

    func pollEventPlaceholder() {
        // TODO: Bridge alvr_poll_event into ALVRSessionManager's event loop.
    }

    func stopPlaceholder() {
        // TODO: Bridge alvr_pause and alvr_destroy for teardown.
    }

    // TODO: Bridge alvr_initialize.
    // TODO: Bridge alvr_resume.
    // TODO: Bridge alvr_pause.
    // TODO: Bridge alvr_destroy.
    // TODO: Bridge alvr_poll_event.
    // TODO: Bridge alvr_send_tracking_and_face_data.
    // TODO: Bridge alvr_send_views_config.
}
