//
//  ALVRSessionDiagnosticsManager.swift
//  Moonlight Vision
//
//  Long-running ALVR core diagnostics without decoder, renderer, or tracking.
//

import Foundation

struct ALVRDecoderConfigSnapshot: Sendable {
    let attempted: Bool
    let success: Bool
    let size: UInt64
    let prefixHex: String?
    let asciiPreview: String?
    let errorDescription: String?
    let triggerReason: String
    let messages: [String]
}

#if canImport(ALVRClientCore)
import ALVRClientCore

private let alvrSessionDiagnosticsMetadataCollector = ALVRDecoderMetadataCollector()

private let alvrSessionDiagnosticsMetadataCallback: @convention(c) (AlvrVideoFrameData) -> Bool = { frameData in
    alvrSessionDiagnosticsMetadataCollector.record(frameData: frameData)
    return true
}
#endif

@MainActor
final class ALVRSessionDiagnosticsManager: ObservableObject, @unchecked Sendable {
    enum State: Equatable {
        case idle
        case starting
        case running
        case stopping
        case stopped
        case failed(String)

        var description: String {
            switch self {
            case .idle:
                return "Idle"
            case .starting:
                return "Starting"
            case .running:
                return "Running"
            case .stopping:
                return "Stopping"
            case .stopped:
                return "Stopped"
            case .failed(let message):
                return "Failed: \(message)"
            }
        }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var eventTagNames: [String] = []
    @Published private(set) var eventTagRawValues: [UInt32] = []
    @Published private(set) var hudMessages: [String] = []
    @Published private(set) var streamingEventSeen = false
    @Published private(set) var decoderConfigEventSeen = false
    @Published private(set) var hapticsEventSeen = false
    @Published private(set) var frameCount = 0
    @Published private(set) var totalBytes: UInt64 = 0
    @Published private(set) var lastTimestampNs: UInt64?
    @Published private(set) var minBufferSize: UInt64?
    @Published private(set) var maxBufferSize: UInt64?
    @Published private(set) var firstFramePrefixHex: String?
    @Published private(set) var lastFramePrefixHex: String?
    @Published private(set) var nalScanEnabled = true
    @Published private(set) var codecGuess = "unknown"
    @Published private(set) var nalUnitCount = 0
    @Published private(set) var hevcVpsCount = 0
    @Published private(set) var hevcSpsCount = 0
    @Published private(set) var hevcPpsCount = 0
    @Published private(set) var hevcTrailCount = 0
    @Published private(set) var hevcNonIdrCount = 0
    @Published private(set) var hevcSliceCount = 0
    @Published private(set) var hevcIdrCount = 0
    @Published private(set) var hevcCraCount = 0
    @Published private(set) var h264SpsCount = 0
    @Published private(set) var h264PpsCount = 0
    @Published private(set) var h264IdrCount = 0
    @Published private(set) var h264NonIdrCount = 0
    @Published private(set) var seiCount = 0
    @Published private(set) var firstNalTypes: [String] = []
    @Published private(set) var hasParameterSets = false
    @Published private(set) var hasIdr = false
    @Published private(set) var parameterSetsReady = false
    @Published private(set) var videoToolboxReady = false
    @Published private(set) var missingDecoderPrerequisites: [String] = []
    @Published private(set) var requiresAppRestart = false
    @Published private(set) var messages: [String] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastStep = "Idle"
    @Published private(set) var decoderConfigSnapshot: ALVRDecoderConfigSnapshot?

    private var diagnosticsTask: Task<Void, Never>?
    private var didReadDecoderConfigSnapshot = false

    var isRunning: Bool {
        if case .running = state { return true }
        if case .starting = state { return true }
        return false
    }

    var isStopping: Bool {
        if case .stopping = state { return true }
        return false
    }

    func start(clientInfo: ALVRClientInfoResult?, isMdnsBroadcasting: Bool) {
        guard !isRunning, !isStopping else {
            return
        }

        guard !requiresAppRestart else {
            fail("Restart the app before running another ALVR core test.")
            return
        }

        guard clientInfo?.success == true else {
            fail("Load ALVR Client Info before starting session diagnostics.")
            return
        }

        guard isMdnsBroadcasting else {
            fail("Start ALVR mDNS Broadcast before starting session diagnostics.")
            return
        }

        resetForStart()

        #if canImport(ALVRClientCore)
        state = .starting
        record("Starting ALVR session diagnostics")

        diagnosticsTask = Task.detached(priority: .userInitiated) { [weak self] in
            await Self.runDiagnosticsLoop(owner: self)
        }
        #else
        fail("ALVRClientCore is not available to this target.")
        #endif
    }

    func stop() {
        guard isRunning else {
            return
        }

        state = .stopping
        lastStep = "Stop requested"
        record("Stop requested")
        diagnosticsTask?.cancel()
    }

    func readDecoderConfigSnapshot(triggerReason: String = "Manual snapshot") {
        guard decoderConfigEventSeen else {
            decoderConfigSnapshot = ALVRDecoderConfigSnapshot(
                attempted: false,
                success: false,
                size: 0,
                prefixHex: nil,
                asciiPreview: nil,
                errorDescription: "Decoder config unavailable.",
                triggerReason: triggerReason,
                messages: [
                    "Decoder config event has not been seen yet.",
                    "Reading decoder config now is disabled to avoid disrupting the ALVR session."
                ]
            )
            return
        }

        guard canReadDecoderConfigSnapshot else {
            decoderConfigSnapshot = ALVRDecoderConfigSnapshot(
                attempted: false,
                success: false,
                size: 0,
                prefixHex: nil,
                asciiPreview: nil,
                errorDescription: "Start session diagnostics and wait for ALVR_EVENT_DECODER_CONFIG before reading decoder config.",
                triggerReason: triggerReason,
                messages: ["Decoder config snapshot not attempted"]
            )
            return
        }

        #if canImport(ALVRClientCore)
        decoderConfigSnapshot = Self.readDecoderConfigSnapshotFromCore(triggerReason: triggerReason)
        didReadDecoderConfigSnapshot = true
        if let decoderConfigSnapshot {
            messages.append(contentsOf: decoderConfigSnapshot.messages)
        }
        #else
        decoderConfigSnapshot = ALVRDecoderConfigSnapshot(
            attempted: true,
            success: false,
            size: 0,
            prefixHex: nil,
            asciiPreview: nil,
            errorDescription: "ALVRClientCore is not available to this target.",
            triggerReason: triggerReason,
            messages: ["ALVRClientCore import unavailable"]
        )
        #endif
    }

    private func resetForStart() {
        diagnosticsTask?.cancel()
        diagnosticsTask = nil
        state = .idle
        elapsedSeconds = 0
        eventTagNames = []
        eventTagRawValues = []
        hudMessages = []
        streamingEventSeen = false
        decoderConfigEventSeen = false
        hapticsEventSeen = false
        frameCount = 0
        totalBytes = 0
        lastTimestampNs = nil
        minBufferSize = nil
        maxBufferSize = nil
        firstFramePrefixHex = nil
        lastFramePrefixHex = nil
        nalScanEnabled = true
        codecGuess = "unknown"
        nalUnitCount = 0
        hevcVpsCount = 0
        hevcSpsCount = 0
        hevcPpsCount = 0
        hevcTrailCount = 0
        hevcNonIdrCount = 0
        hevcSliceCount = 0
        hevcIdrCount = 0
        hevcCraCount = 0
        h264SpsCount = 0
        h264PpsCount = 0
        h264IdrCount = 0
        h264NonIdrCount = 0
        seiCount = 0
        firstNalTypes = []
        hasParameterSets = false
        hasIdr = false
        parameterSetsReady = false
        videoToolboxReady = false
        missingDecoderPrerequisites = []
        requiresAppRestart = false
        messages = []
        errorMessage = nil
        lastStep = "Idle"
        decoderConfigSnapshot = nil
        didReadDecoderConfigSnapshot = false
    }

    private func record(_ message: String) {
        lastStep = message
        messages.append(message)
    }

    private func fail(_ message: String) {
        state = .failed(message)
        errorMessage = message
        lastStep = message
        messages.append(message)
    }

    private func applySnapshot(_ snapshot: ALVRDecoderMetadataSnapshot) {
        frameCount = snapshot.frameCount
        totalBytes = snapshot.totalBytes
        lastTimestampNs = snapshot.lastTimestampNs
        minBufferSize = snapshot.minBufferSize
        maxBufferSize = snapshot.maxBufferSize
        firstFramePrefixHex = snapshot.firstFramePrefixHex
        lastFramePrefixHex = snapshot.lastFramePrefixHex
        nalScanEnabled = snapshot.nalScanEnabled
        codecGuess = snapshot.codecGuess
        nalUnitCount = snapshot.nalUnitCount
        hevcVpsCount = snapshot.hevcVpsCount
        hevcSpsCount = snapshot.hevcSpsCount
        hevcPpsCount = snapshot.hevcPpsCount
        hevcTrailCount = snapshot.hevcTrailCount
        hevcNonIdrCount = snapshot.hevcNonIdrCount
        hevcSliceCount = snapshot.hevcSliceCount
        hevcIdrCount = snapshot.hevcIdrCount
        hevcCraCount = snapshot.hevcCraCount
        h264SpsCount = snapshot.h264SpsCount
        h264PpsCount = snapshot.h264PpsCount
        h264IdrCount = snapshot.h264IdrCount
        h264NonIdrCount = snapshot.h264NonIdrCount
        seiCount = snapshot.seiCount
        firstNalTypes = snapshot.firstNalTypes
        hasParameterSets = snapshot.hasParameterSets
        hasIdr = snapshot.hasIdr
        parameterSetsReady = snapshot.parameterSetsReady
        videoToolboxReady = snapshot.videoToolboxReady
        missingDecoderPrerequisites = snapshot.missingDecoderPrerequisites
    }

    var canReadDecoderConfigSnapshot: Bool {
        guard case .running = state else {
            return false
        }
        return !requiresAppRestart && !didReadDecoderConfigSnapshot && decoderConfigEventSeen
    }

    #if canImport(ALVRClientCore)
    private nonisolated static func readDecoderConfigSnapshotFromCore(triggerReason: String) -> ALVRDecoderConfigSnapshot {
        let safetyLimit = 2 * 1024 * 1024
        var messages = ["Calling alvr_get_decoder_config(nil)"]
        let requestedSize = alvr_get_decoder_config(nil)
        messages.append("alvr_get_decoder_config(nil) returned \(requestedSize) bytes")

        guard requestedSize > 0 else {
            return ALVRDecoderConfigSnapshot(
                attempted: true,
                success: false,
                size: 0,
                prefixHex: nil,
                asciiPreview: nil,
                errorDescription: "Decoder config is empty.",
                triggerReason: triggerReason,
                messages: messages
            )
        }

        guard requestedSize <= UInt64(safetyLimit) else {
            return ALVRDecoderConfigSnapshot(
                attempted: true,
                success: false,
                size: requestedSize,
                prefixHex: nil,
                asciiPreview: nil,
                errorDescription: "Decoder config size exceeds \(safetyLimit) byte safety limit.",
                triggerReason: triggerReason,
                messages: messages
            )
        }

        var buffer = [CChar](repeating: 0, count: Int(requestedSize))
        let returnedSize = buffer.withUnsafeMutableBufferPointer { bufferPointer in
            alvr_get_decoder_config(bufferPointer.baseAddress)
        }
        messages.append("alvr_get_decoder_config(buffer) returned \(returnedSize) bytes")

        let bytes = buffer.map { UInt8(bitPattern: $0) }
        let prefixBytes = bytes.prefix(64)
        let prefixHex = prefixBytes
            .map { String(format: "%02X", $0) }
            .joined(separator: " ")
        let asciiPreview = prefixBytes
            .map { byte -> String in
                if byte >= 32 && byte <= 126 {
                    return String(UnicodeScalar(Int(byte))!)
                }
                return "."
            }
            .joined()

        return ALVRDecoderConfigSnapshot(
            attempted: true,
            success: true,
            size: requestedSize,
            prefixHex: prefixHex.isEmpty ? nil : prefixHex,
            asciiPreview: asciiPreview.isEmpty ? nil : asciiPreview,
            errorDescription: nil,
            triggerReason: triggerReason,
            messages: messages
        )
    }

    private nonisolated static func runDiagnosticsLoop(owner: ALVRSessionDiagnosticsManager?) async {
        guard let owner else {
            return
        }

        var didResume = false
        var didPause = false
        let startDate = Date()
        var lastUiRefreshDate = Date.distantPast
        var eventTagNames: [String] = []
        var eventTagRawValues: [UInt32] = []
        var hudMessages: [String] = []
        var streamingEventSeen = false
        var decoderConfigEventSeen = false
        var hapticsEventSeen = false

        func updateMain(_ update: @escaping @MainActor () -> Void) async {
            await MainActor.run(body: update)
        }

        func record(_ message: String) async {
            await updateMain {
                owner.lastStep = message
                owner.messages.append(message)
            }
            print("[ALVR Session Diagnostics] \(message)")
        }

        func refreshUi(force: Bool = false) async {
            let now = Date()
            guard force || now.timeIntervalSince(lastUiRefreshDate) >= 1.0 else {
                return
            }
            lastUiRefreshDate = now
            let snapshot = alvrSessionDiagnosticsMetadataCollector.snapshot()
            await updateMain {
                owner.elapsedSeconds = Int(now.timeIntervalSince(startDate))
                owner.eventTagNames = eventTagNames
                owner.eventTagRawValues = eventTagRawValues
                owner.hudMessages = hudMessages
                owner.streamingEventSeen = streamingEventSeen
                owner.decoderConfigEventSeen = decoderConfigEventSeen
                owner.hapticsEventSeen = hapticsEventSeen
                owner.applySnapshot(snapshot)
            }
        }

        defer {
            Task { @MainActor in
                owner.diagnosticsTask = nil
            }
        }

        alvrSessionDiagnosticsMetadataCollector.reset()
        alvrSessionDiagnosticsMetadataCollector.start()

        await record("Calling alvr_initialize")
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
        }
        await record("Called alvr_initialize(capabilities)")

        await record("Calling alvr_initialize_logging")
        alvr_initialize_logging()
        await record("Called alvr_initialize_logging()")

        await record("Calling alvr_set_decoder_input_callback")
        alvr_set_decoder_input_callback(nil, alvrSessionDiagnosticsMetadataCallback)
        await record("Called alvr_set_decoder_input_callback(nil, metadataCallback)")

        await record("Calling alvr_resume")
        alvr_resume()
        didResume = true
        await record("Called alvr_resume()")

        await updateMain {
            owner.state = .running
        }

        while !Task.isCancelled {
            var event = AlvrEvent()
            if alvr_poll_event(&event) {
                let rawValue = UInt32(event.tag)
                let tagName = Self.eventTagName(for: rawValue)

                eventTagRawValues.append(rawValue)
                eventTagNames.append(tagName)
                await record("Polled event tag: \(tagName) (\(rawValue))")

                switch rawValue {
                case UInt32(ALVR_EVENT_HUD_MESSAGE_UPDATED.rawValue):
                    let hudReadResult = Self.readHudMessage()
                    hudMessages.append(hudReadResult.message)
                    await record("Read HUD message: \(hudReadResult.message)")
                    if hudReadResult.wasTruncated {
                        await record("HUD message may be truncated; alvr_hud_message returned \(hudReadResult.returnedLength) bytes for \(hudReadResult.bufferSize)-byte buffer")
                    }
                case UInt32(ALVR_EVENT_STREAMING_STARTED.rawValue),
                    UInt32(ALVR_EVENT_STREAMING_STOPPED.rawValue):
                    streamingEventSeen = true
                case UInt32(ALVR_EVENT_DECODER_CONFIG.rawValue):
                    decoderConfigEventSeen = true
                case UInt32(ALVR_EVENT_HAPTICS.rawValue):
                    hapticsEventSeen = true
                default:
                    break
                }
            }

            await refreshUi()
            try? await Task.sleep(nanoseconds: 1_000_000)
        }

        await refreshUi(force: true)

        if didResume {
            await record("Calling alvr_pause")
            await updateMain {
                owner.state = .stopping
            }
            alvr_pause()
            didPause = true
            await record("Called alvr_pause()")
        }

        alvrSessionDiagnosticsMetadataCollector.stop()
        await refreshUi(force: true)
        await record("Skipped alvr_destroy() after resume. Restart the app before running another ALVR core test.")

        await updateMain {
            owner.requiresAppRestart = true
            owner.state = didPause ? .stopped : .failed("ALVR session diagnostics stopped before pause completed.")
        }
    }

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
