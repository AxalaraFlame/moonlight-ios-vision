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

struct ControlledResumeSmokeResult: Sendable {
    let success: Bool
    let messages: [String]
    let didInitialize: Bool
    let didResume: Bool
    let didPause: Bool
    let didDestroy: Bool
    let destroySkipped: Bool
    let requiresAppRestart: Bool
    let polledEventCount: Int
    let eventTagRawValues: [UInt32]
    let eventTagNames: [String]
    let hudMessages: [String]
    let dangerousEventSeen: Bool
    let errorDescription: String?
    let durationMilliseconds: Int
    let lastStep: String
}

@MainActor
final class ALVRClientCoreBridge {
    static let shared = ALVRClientCoreBridge()

    private var isLifecycleSmokeTestRunning = false
    private var isControlledResumeSmokeTestRunning = false

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

    func runControlledResumeSmokeTest(durationMilliseconds: Int = 1500) async -> ControlledResumeSmokeResult {
        guard !isControlledResumeSmokeTestRunning else {
            return ControlledResumeSmokeResult(
                success: false,
                messages: ["Controlled resume smoke test already running"],
                didInitialize: false,
                didResume: false,
                didPause: false,
                didDestroy: false,
                destroySkipped: false,
                requiresAppRestart: false,
                polledEventCount: 0,
                eventTagRawValues: [],
                eventTagNames: [],
                hudMessages: [],
                dangerousEventSeen: false,
                errorDescription: "Controlled resume smoke test already running.",
                durationMilliseconds: 0,
                lastStep: "Already running"
            )
        }

        isControlledResumeSmokeTestRunning = true
        defer { isControlledResumeSmokeTestRunning = false }

        #if canImport(ALVRClientCore)
        let cappedDurationMilliseconds = min(max(durationMilliseconds, 100), 3000)
        return await Task.detached(priority: .userInitiated) {
            await Self.performControlledResumeSmokeTest(durationMilliseconds: cappedDurationMilliseconds)
        }.value
        #else
        return ControlledResumeSmokeResult(
            success: false,
            messages: ["ALVRClientCore import unavailable"],
            didInitialize: false,
            didResume: false,
            didPause: false,
            didDestroy: false,
            destroySkipped: false,
            requiresAppRestart: false,
            polledEventCount: 0,
            eventTagRawValues: [],
            eventTagNames: [],
            hudMessages: [],
            dangerousEventSeen: false,
            errorDescription: "ALVRClientCore is not available to this target.",
            durationMilliseconds: 0,
            lastStep: "ALVRClientCore unavailable"
        )
        #endif
    }

    #if canImport(ALVRClientCore)
    private nonisolated static func performControlledResumeSmokeTest(durationMilliseconds: Int) async -> ControlledResumeSmokeResult {
        var messages = ["ALVRClientCore import available"]
        var didInitialize = false
        var didResume = false
        var didPause = false
        let didDestroy = false
        let destroySkipped = true
        let requiresAppRestart = true
        var eventTagRawValues: [UInt32] = []
        var eventTagNames: [String] = []
        var hudMessages: [String] = []
        var dangerousEventSeen = false
        var lastStep = "Not started"
        let startDate = Date()
        let deadline = Date().addingTimeInterval(Double(durationMilliseconds) / 1000.0)

        func record(_ message: String) {
            lastStep = message
            messages.append(message)
            print("[ALVR Controlled Resume Smoke] \(message)")
        }

        defer {
            if didResume && !didPause {
                record("Calling alvr_pause")
                alvr_pause()
                didPause = true
                record("Called alvr_pause() from cleanup")
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

            record("Calling alvr_initialize")
            alvr_initialize(capabilities)
            didInitialize = true
            record("Called alvr_initialize(capabilities)")
        }

        record("Calling alvr_initialize_logging")
        alvr_initialize_logging()
        record("Called alvr_initialize_logging()")

        record("Calling alvr_resume")
        alvr_resume()
        didResume = true
        record("Called alvr_resume()")

        record("Entering limited poll loop for \(durationMilliseconds) ms")
        while Date() < deadline {
            var event = AlvrEvent()
            if alvr_poll_event(&event) {
                let rawValue = UInt32(event.tag)
                let tagName = Self.eventTagName(for: rawValue)

                eventTagRawValues.append(rawValue)
                eventTagNames.append(tagName)
                record("Polled event tag: \(tagName) (\(rawValue))")

                if rawValue == UInt32(ALVR_EVENT_HUD_MESSAGE_UPDATED.rawValue) {
                    let hudReadResult = Self.readHudMessage()
                    hudMessages.append(hudReadResult.message)
                    record("Read HUD message: \(hudReadResult.message)")
                    if hudReadResult.wasTruncated {
                        record("HUD message may be truncated; alvr_hud_message returned \(hudReadResult.returnedLength) bytes for \(hudReadResult.bufferSize)-byte buffer")
                    }
                }

                if Self.isDangerousEventTag(rawValue) {
                    dangerousEventSeen = true
                    record("Dangerous event seen; decoder/renderer not attached. Stopped polling early.")
                    break
                }
            }

            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        record("Leaving poll loop")

        if eventTagRawValues.isEmpty {
            record("No ALVR events observed during controlled resume window")
        }

        record("Calling alvr_pause")
        alvr_pause()
        didPause = true
        record("Called alvr_pause()")

        record("Skipped alvr_destroy() after resume because previous attempt blocked after alvr_pause(). Restart the app before running another ALVR core test.")

        return ControlledResumeSmokeResult(
            success: didInitialize && didResume && didPause,
            messages: messages,
            didInitialize: didInitialize,
            didResume: didResume,
            didPause: didPause,
            didDestroy: didDestroy,
            destroySkipped: destroySkipped,
            requiresAppRestart: requiresAppRestart,
            polledEventCount: eventTagRawValues.count,
            eventTagRawValues: eventTagRawValues,
            eventTagNames: eventTagNames,
            hudMessages: hudMessages,
            dangerousEventSeen: dangerousEventSeen,
            errorDescription: nil,
            durationMilliseconds: Int(Date().timeIntervalSince(startDate) * 1000),
            lastStep: lastStep
        )
    }
    #endif

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

    #if canImport(ALVRClientCore)
    private nonisolated static func eventTagName(for rawValue: UInt32) -> String {
        switch rawValue {
        case UInt32(ALVR_EVENT_HUD_MESSAGE_UPDATED.rawValue):
            return "ALVR_EVENT_HUD_MESSAGE_UPDATED"
        case UInt32(ALVR_EVENT_STREAMING_STARTED.rawValue):
            return "ALVR_EVENT_STREAMING_STARTED"
        case UInt32(ALVR_EVENT_STREAMING_STOPPED.rawValue):
            return "ALVR_EVENT_STREAMING_STOPPED"
        case UInt32(ALVR_EVENT_HAPTICS.rawValue):
            return "ALVR_EVENT_HAPTICS"
        case UInt32(ALVR_EVENT_DECODER_CONFIG.rawValue):
            return "ALVR_EVENT_DECODER_CONFIG"
        case UInt32(ALVR_EVENT_REAL_TIME_CONFIG.rawValue):
            return "ALVR_EVENT_REAL_TIME_CONFIG"
        default:
            return "UNKNOWN_EVENT_TAG"
        }
    }

    private nonisolated static func isDangerousEventTag(_ rawValue: UInt32) -> Bool {
        rawValue == UInt32(ALVR_EVENT_STREAMING_STARTED.rawValue)
            || rawValue == UInt32(ALVR_EVENT_DECODER_CONFIG.rawValue)
            || rawValue == UInt32(ALVR_EVENT_HAPTICS.rawValue)
    }

    private nonisolated static func readHudMessage() -> (message: String, returnedLength: UInt64, bufferSize: Int, wasTruncated: Bool) {
        let bufferSize = 4096
        var buffer = [CChar](repeating: 0, count: bufferSize)
        let returnedLength = buffer.withUnsafeMutableBufferPointer { bufferPointer in
            alvr_hud_message(bufferPointer.baseAddress)
        }

        buffer[bufferSize - 1] = 0
        let message = buffer.withUnsafeBufferPointer { bufferPointer in
            String(cString: bufferPointer.baseAddress!)
        }

        return (
            message: message,
            returnedLength: returnedLength,
            bufferSize: bufferSize,
            wasTruncated: returnedLength >= UInt64(bufferSize)
        )
    }
    #endif
}
