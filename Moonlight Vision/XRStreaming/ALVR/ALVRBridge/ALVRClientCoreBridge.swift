//
//  ALVRClientCoreBridge.swift
//  Moonlight Vision
//
//  Bridge skeleton for the generated ALVRClientCore.xcframework.
//

import Foundation
import Darwin

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

struct ALVRClientInfoResult: Sendable {
    let success: Bool
    let serviceType: String?
    let rawHostname: String?
    let deviceId: String?
    let protocolId: String?
    let localIPv4Addresses: [String]
    let messages: [String]
    let errorDescription: String?
    let requiresAppRestart: Bool
}

struct ALVRDecoderMetadataSnapshot: Sendable {
    let frameCount: Int
    let totalBytes: UInt64
    let lastTimestampNs: UInt64?
    let minBufferSize: UInt64?
    let maxBufferSize: UInt64?
    let firstFramePrefixHex: String?
    let lastFramePrefixHex: String?
    let nalScanEnabled: Bool
    let codecGuess: String
    let nalUnitCount: Int
    let hevcVpsCount: Int
    let hevcSpsCount: Int
    let hevcPpsCount: Int
    let hevcTrailCount: Int
    let hevcNonIdrCount: Int
    let hevcSliceCount: Int
    let hevcIdrCount: Int
    let hevcCraCount: Int
    let h264SpsCount: Int
    let h264PpsCount: Int
    let h264IdrCount: Int
    let h264NonIdrCount: Int
    let seiCount: Int
    let firstNalTypes: [String]
    let hasParameterSets: Bool
    let hasIdr: Bool
    let parameterSetsReady: Bool
    let videoToolboxReady: Bool
    let missingDecoderPrerequisites: [String]
    let hevcVpsData: [UInt8]
    let hevcSpsData: [UInt8]
    let hevcPpsData: [UInt8]
    let h264SpsData: [UInt8]
    let h264PpsData: [UInt8]
    let messages: [String]
}

struct ALVRDecoderMetadataScanResult: Sendable {
    let success: Bool
    let scanCompleted: Bool
    let receivedVideoFrames: Bool
    let messages: [String]
    let didInitialize: Bool
    let didSetDecoderCallback: Bool
    let didResume: Bool
    let didPause: Bool
    let didDestroy: Bool
    let destroySkipped: Bool
    let requiresAppRestart: Bool
    let polledEventCount: Int
    let eventTagNames: [String]
    let eventTagRawValues: [UInt32]
    let streamingRelatedEventSeen: Bool
    let decoderConfigEventSeen: Bool
    let frameCount: Int
    let totalBytes: UInt64
    let lastTimestampNs: UInt64?
    let minBufferSize: UInt64?
    let maxBufferSize: UInt64?
    let firstFramePrefixHex: String?
    let lastFramePrefixHex: String?
    let nalScanEnabled: Bool
    let codecGuess: String
    let nalUnitCount: Int
    let hevcVpsCount: Int
    let hevcSpsCount: Int
    let hevcPpsCount: Int
    let hevcTrailCount: Int
    let hevcNonIdrCount: Int
    let hevcSliceCount: Int
    let hevcIdrCount: Int
    let hevcCraCount: Int
    let h264SpsCount: Int
    let h264PpsCount: Int
    let h264IdrCount: Int
    let h264NonIdrCount: Int
    let seiCount: Int
    let firstNalTypes: [String]
    let hasParameterSets: Bool
    let hasIdr: Bool
    let parameterSetsReady: Bool
    let videoToolboxReady: Bool
    let missingDecoderPrerequisites: [String]
    let noFramesReceivedMessage: String?
    let durationMilliseconds: Int
    let lastStep: String
    let errorDescription: String?
}

#if canImport(ALVRClientCore)
struct ALVRDecoderCopiedFrame: Sendable {
    let data: Data
    let timestampNs: UInt64
    let containsIDR: Bool
}

final class ALVRDecoderMetadataCollector: @unchecked Sendable {
    private struct NalScanResult {
        var nalUnitCount = 0
        var hevcVpsCount = 0
        var hevcSpsCount = 0
        var hevcPpsCount = 0
        var hevcTrailCount = 0
        var hevcNonIdrCount = 0
        var hevcSliceCount = 0
        var hevcIdrCount = 0
        var hevcCraCount = 0
        var h264SpsCount = 0
        var h264PpsCount = 0
        var h264IdrCount = 0
        var h264NonIdrCount = 0
        var seiCount = 0
        var firstNalTypes: [String] = []
        var hevcVpsData: [UInt8] = []
        var hevcSpsData: [UInt8] = []
        var hevcPpsData: [UInt8] = []
        var h264SpsData: [UInt8] = []
        var h264PpsData: [UInt8] = []
    }

    private let lock = NSLock()
    private var isActive = false
    private var frameCount = 0
    private var totalBytes: UInt64 = 0
    private var lastTimestampNs: UInt64?
    private var minBufferSize: UInt64?
    private var maxBufferSize: UInt64?
    private var firstFramePrefixHex: String?
    private var lastFramePrefixHex: String?
    private var nalUnitCount = 0
    private var hevcVpsCount = 0
    private var hevcSpsCount = 0
    private var hevcPpsCount = 0
    private var hevcTrailCount = 0
    private var hevcNonIdrCount = 0
    private var hevcSliceCount = 0
    private var hevcIdrCount = 0
    private var hevcCraCount = 0
    private var h264SpsCount = 0
    private var h264PpsCount = 0
    private var h264IdrCount = 0
    private var h264NonIdrCount = 0
    private var seiCount = 0
    private var firstNalTypes: [String] = []
    private var hevcVpsData: [UInt8] = []
    private var hevcSpsData: [UInt8] = []
    private var hevcPpsData: [UInt8] = []
    private var h264SpsData: [UInt8] = []
    private var h264PpsData: [UInt8] = []
    private var messages: [String] = []
    private var frameFeedSink: ((ALVRDecoderCopiedFrame) -> Void)?
    private var frameFeedCopiedCount = 0
    private var frameFeedInspectedCount = 0
    private let frameFeedMaxFrames = 3
    private let frameFeedMaxFrameSize: UInt64 = 2 * 1024 * 1024

    func reset() {
        lock.lock()
        defer { lock.unlock() }

        isActive = false
        frameCount = 0
        totalBytes = 0
        lastTimestampNs = nil
        minBufferSize = nil
        maxBufferSize = nil
        firstFramePrefixHex = nil
        lastFramePrefixHex = nil
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
        hevcVpsData = []
        hevcSpsData = []
        hevcPpsData = []
        h264SpsData = []
        h264PpsData = []
        messages = []
        frameFeedSink = nil
        frameFeedCopiedCount = 0
        frameFeedInspectedCount = 0
    }

    func start() {
        lock.lock()
        defer { lock.unlock() }

        isActive = true
        messages.append("Decoder metadata collector started")
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }

        isActive = false
        frameFeedSink = nil
        messages.append("Decoder metadata collector stopped")
    }

    func configureFrameFeedSink(_ sink: ((ALVRDecoderCopiedFrame) -> Void)?) {
        lock.lock()
        defer { lock.unlock() }

        frameFeedSink = sink
        frameFeedCopiedCount = 0
        frameFeedInspectedCount = 0
        if sink == nil {
            messages.append("HEVC frame feed smoke test disabled")
        } else {
            messages.append("HEVC frame feed smoke test enabled; will copy at most 3 frames")
        }
    }

    func record(frameData: AlvrVideoFrameData) {
        let bufferSize = frameData.buffer_size
        let timestamp = frameData.timestamp_ns
        let prefixHex = Self.prefixHex(bufferPointer: frameData.buffer_ptr, bufferSize: bufferSize)
        let nalScanResult = Self.scanNalUnits(bufferPointer: frameData.buffer_ptr, bufferSize: bufferSize)
        var frameFeedSinkToCall: ((ALVRDecoderCopiedFrame) -> Void)?
        var shouldCopyFrameForFeed = false
        let containsIDR = nalScanResult.hevcIdrCount > 0 || nalScanResult.hevcCraCount > 0 || nalScanResult.h264IdrCount > 0

        lock.lock()
        guard isActive else {
            lock.unlock()
            return
        }

        frameCount += 1
        totalBytes &+= bufferSize
        lastTimestampNs = timestamp
        minBufferSize = minBufferSize.map { min($0, bufferSize) } ?? bufferSize
        maxBufferSize = maxBufferSize.map { max($0, bufferSize) } ?? bufferSize

        if firstFramePrefixHex == nil {
            firstFramePrefixHex = prefixHex
        }
        lastFramePrefixHex = prefixHex
        nalUnitCount += nalScanResult.nalUnitCount
        hevcVpsCount += nalScanResult.hevcVpsCount
        hevcSpsCount += nalScanResult.hevcSpsCount
        hevcPpsCount += nalScanResult.hevcPpsCount
        hevcTrailCount += nalScanResult.hevcTrailCount
        hevcNonIdrCount += nalScanResult.hevcNonIdrCount
        hevcSliceCount += nalScanResult.hevcSliceCount
        hevcIdrCount += nalScanResult.hevcIdrCount
        hevcCraCount += nalScanResult.hevcCraCount
        h264SpsCount += nalScanResult.h264SpsCount
        h264PpsCount += nalScanResult.h264PpsCount
        h264IdrCount += nalScanResult.h264IdrCount
        h264NonIdrCount += nalScanResult.h264NonIdrCount
        seiCount += nalScanResult.seiCount

        for nalType in nalScanResult.firstNalTypes where firstNalTypes.count < 16 {
            firstNalTypes.append(nalType)
        }

        if hevcVpsData.isEmpty {
            hevcVpsData = nalScanResult.hevcVpsData
        }
        if hevcSpsData.isEmpty {
            hevcSpsData = nalScanResult.hevcSpsData
        }
        if hevcPpsData.isEmpty {
            hevcPpsData = nalScanResult.hevcPpsData
        }
        if h264SpsData.isEmpty {
            h264SpsData = nalScanResult.h264SpsData
        }
        if h264PpsData.isEmpty {
            h264PpsData = nalScanResult.h264PpsData
        }

        if bufferSize == 0 {
            messages.append("Received zero-byte decoder frame at \(timestamp)")
        } else if frameData.buffer_ptr == nil {
            messages.append("Received decoder frame with nil buffer at \(timestamp)")
        }

        if let frameFeedSink,
           frameFeedCopiedCount < frameFeedMaxFrames,
           frameData.buffer_ptr != nil,
           bufferSize > 0,
           bufferSize <= frameFeedMaxFrameSize {
            frameFeedInspectedCount += 1
            let shouldPreferIDR = containsIDR
            let shouldFallbackAfterWarmup = frameFeedInspectedCount > 30 || frameFeedCopiedCount > 0
            if shouldPreferIDR || shouldFallbackAfterWarmup {
                frameFeedCopiedCount += 1
                shouldCopyFrameForFeed = true
                frameFeedSinkToCall = frameFeedSink
                messages.append("Copying HEVC frame \(frameFeedCopiedCount) for VideoToolbox feed smoke test at \(timestamp)")
            }
        }
        lock.unlock()

        if shouldCopyFrameForFeed,
           let frameFeedSinkToCall,
           let bufferPointer = frameData.buffer_ptr,
           bufferSize <= frameFeedMaxFrameSize {
            let data = Data(bytes: bufferPointer, count: Int(bufferSize))
            frameFeedSinkToCall(ALVRDecoderCopiedFrame(
                data: data,
                timestampNs: timestamp,
                containsIDR: containsIDR
            ))
        }
    }

    func snapshot() -> ALVRDecoderMetadataSnapshot {
        lock.lock()
        defer { lock.unlock() }

        let hasHevcSignals = hevcVpsCount > 0 || hevcSpsCount > 0 || hevcPpsCount > 0 || hevcIdrCount > 0 || hevcCraCount > 0 || hevcSliceCount > 0
        let hasH264Signals = h264SpsCount > 0 || h264PpsCount > 0 || h264IdrCount > 0 || h264NonIdrCount > 0
        let hevcParameterSetsReady = hevcVpsCount > 0 && hevcSpsCount > 0 && hevcPpsCount > 0
        let h264ParameterSetsReady = h264SpsCount > 0 && h264PpsCount > 0
        var missingDecoderPrerequisites: [String] = []
        let codecGuess: String
        if hasHevcSignals && hasH264Signals {
            codecGuess = "mixed/ambiguous"
            if !hevcParameterSetsReady {
                missingDecoderPrerequisites.append("HEVC VPS/SPS/PPS not found")
            }
            if !h264ParameterSetsReady {
                missingDecoderPrerequisites.append("H264 SPS/PPS not found")
            }
        } else if hasHevcSignals {
            codecGuess = "hevc"
            if !hevcParameterSetsReady {
                missingDecoderPrerequisites.append("HEVC VPS/SPS/PPS not found")
            }
        } else if hasH264Signals {
            codecGuess = "h264"
            if !h264ParameterSetsReady {
                missingDecoderPrerequisites.append("H264 SPS/PPS not found")
            }
        } else {
            codecGuess = "unknown"
            missingDecoderPrerequisites.append("No H264 or HEVC parameter sets or slices found")
        }
        let parameterSetsReady: Bool
        if codecGuess == "hevc" {
            parameterSetsReady = hevcParameterSetsReady
        } else if codecGuess == "h264" {
            parameterSetsReady = h264ParameterSetsReady
        } else {
            parameterSetsReady = false
        }

        return ALVRDecoderMetadataSnapshot(
            frameCount: frameCount,
            totalBytes: totalBytes,
            lastTimestampNs: lastTimestampNs,
            minBufferSize: minBufferSize,
            maxBufferSize: maxBufferSize,
            firstFramePrefixHex: firstFramePrefixHex,
            lastFramePrefixHex: lastFramePrefixHex,
            nalScanEnabled: true,
            codecGuess: codecGuess,
            nalUnitCount: nalUnitCount,
            hevcVpsCount: hevcVpsCount,
            hevcSpsCount: hevcSpsCount,
            hevcPpsCount: hevcPpsCount,
            hevcTrailCount: hevcTrailCount,
            hevcNonIdrCount: hevcNonIdrCount,
            hevcSliceCount: hevcSliceCount,
            hevcIdrCount: hevcIdrCount,
            hevcCraCount: hevcCraCount,
            h264SpsCount: h264SpsCount,
            h264PpsCount: h264PpsCount,
            h264IdrCount: h264IdrCount,
            h264NonIdrCount: h264NonIdrCount,
            seiCount: seiCount,
            firstNalTypes: firstNalTypes,
            hasParameterSets: parameterSetsReady,
            hasIdr: hevcIdrCount > 0 || hevcCraCount > 0 || h264IdrCount > 0,
            parameterSetsReady: parameterSetsReady,
            videoToolboxReady: parameterSetsReady,
            missingDecoderPrerequisites: missingDecoderPrerequisites,
            hevcVpsData: hevcVpsData,
            hevcSpsData: hevcSpsData,
            hevcPpsData: hevcPpsData,
            h264SpsData: h264SpsData,
            h264PpsData: h264PpsData,
            messages: messages
        )
    }

    private static func prefixHex(bufferPointer: UnsafePointer<UInt8>?, bufferSize: UInt64) -> String? {
        guard let bufferPointer, bufferSize > 0 else {
            return nil
        }

        let prefixCount = min(Int(bufferSize), 16)
        var parts: [String] = []
        parts.reserveCapacity(prefixCount)

        for index in 0..<prefixCount {
            parts.append(String(format: "%02X", bufferPointer.advanced(by: index).pointee))
        }

        return parts.joined(separator: " ")
    }

    private static func scanNalUnits(bufferPointer: UnsafePointer<UInt8>?, bufferSize: UInt64) -> NalScanResult {
        guard let bufferPointer, bufferSize >= 4 else {
            return NalScanResult()
        }

        let scanLimit = min(Int(bufferSize), 256 * 1024)
        var result = NalScanResult()
        let starts = annexBStarts(bufferPointer: bufferPointer, scanLimit: scanLimit)

        for startIndex in starts.indices {
            let payloadStart = starts[startIndex].payloadIndex
            let payloadEnd = startIndex + 1 < starts.count ? starts[startIndex + 1].startCodeIndex : scanLimit
            guard payloadStart < payloadEnd else {
                continue
            }

            let headerByte = bufferPointer.advanced(by: payloadStart).pointee
            recordNalHeader(headerByte, into: &result)
            copyParameterSetIfNeeded(
                headerByte: headerByte,
                payloadStart: payloadStart,
                payloadEnd: payloadEnd,
                bufferPointer: bufferPointer,
                result: &result
            )
        }

        return result
    }

    private static func annexBStarts(
        bufferPointer: UnsafePointer<UInt8>,
        scanLimit: Int
    ) -> [(startCodeIndex: Int, payloadIndex: Int)] {
        var starts: [(startCodeIndex: Int, payloadIndex: Int)] = []
        var index = 0

        while index + 4 < scanLimit {
            if bufferPointer.advanced(by: index).pointee == 0,
               bufferPointer.advanced(by: index + 1).pointee == 0,
               bufferPointer.advanced(by: index + 2).pointee == 1 {
                starts.append((index, index + 3))
                index += 3
            } else if index + 4 < scanLimit,
                      bufferPointer.advanced(by: index).pointee == 0,
                      bufferPointer.advanced(by: index + 1).pointee == 0,
                      bufferPointer.advanced(by: index + 2).pointee == 0,
                      bufferPointer.advanced(by: index + 3).pointee == 1 {
                starts.append((index, index + 4))
                index += 4
            } else {
                index += 1
            }
        }

        return starts
    }

    private static func copyParameterSetIfNeeded(
        headerByte: UInt8,
        payloadStart: Int,
        payloadEnd: Int,
        bufferPointer: UnsafePointer<UInt8>,
        result: inout NalScanResult
    ) {
        let maxSingleParameterSetSize = 64 * 1024
        let maxTotalParameterSetSize = 256 * 1024
        let nalSize = payloadEnd - payloadStart
        guard nalSize > 0, nalSize <= maxSingleParameterSetSize else {
            return
        }

        let totalStoredBytes = result.hevcVpsData.count
            + result.hevcSpsData.count
            + result.hevcPpsData.count
            + result.h264SpsData.count
            + result.h264PpsData.count
        guard totalStoredBytes + nalSize <= maxTotalParameterSetSize else {
            return
        }

        let hevcNalType = Int((headerByte & 0x7E) >> 1)
        let h264NalType = Int(headerByte & 0x1F)
        let looksLikeCommonHevcHeader = (headerByte & 0x01) == 0
        let copiedNal = Array(UnsafeBufferPointer(
            start: bufferPointer.advanced(by: payloadStart),
            count: nalSize
        ))

        if looksLikeCommonHevcHeader {
            switch hevcNalType {
            case 32 where result.hevcVpsData.isEmpty:
                result.hevcVpsData = copiedNal
            case 33 where result.hevcSpsData.isEmpty:
                result.hevcSpsData = copiedNal
            case 34 where result.hevcPpsData.isEmpty:
                result.hevcPpsData = copiedNal
            default:
                break
            }
        }

        switch h264NalType {
        case 7 where result.h264SpsData.isEmpty:
            result.h264SpsData = copiedNal
        case 8 where result.h264PpsData.isEmpty:
            result.h264PpsData = copiedNal
        default:
            break
        }
    }

    private static func recordNalHeader(_ headerByte: UInt8, into result: inout NalScanResult) {
        let hevcNalType = Int((headerByte & 0x7E) >> 1)
        let h264NalType = Int(headerByte & 0x1F)
        let looksLikeCommonHevcHeader = (headerByte & 0x01) == 0
        var labels: [String] = []

        result.nalUnitCount += 1

        if looksLikeCommonHevcHeader {
            switch hevcNalType {
            case 32:
                result.hevcVpsCount += 1
                labels.append("HEVC_VPS(32)")
            case 33:
                result.hevcSpsCount += 1
                labels.append("HEVC_SPS(33)")
            case 34:
                result.hevcPpsCount += 1
                labels.append("HEVC_PPS(34)")
            case 19:
                result.hevcIdrCount += 1
                labels.append("HEVC_IDR_W_RADL(19)")
            case 20:
                result.hevcIdrCount += 1
                labels.append("HEVC_IDR_N_LP(20)")
            case 21:
                result.hevcCraCount += 1
                labels.append("HEVC_CRA(21)")
            case 39:
                result.seiCount += 1
                labels.append("HEVC_PREFIX_SEI(39)")
            case 40:
                result.seiCount += 1
                labels.append("HEVC_SUFFIX_SEI(40)")
            case 0, 1:
                result.hevcTrailCount += 1
                result.hevcNonIdrCount += 1
                result.hevcSliceCount += 1
                labels.append("HEVC_TRAIL(\(hevcNalType))")
            case 2...9:
                result.hevcNonIdrCount += 1
                result.hevcSliceCount += 1
                labels.append("HEVC_SLICE(\(hevcNalType))")
            default:
                break
            }
        }

        switch h264NalType {
        case 7:
            result.h264SpsCount += 1
            labels.append("H264_SPS(7)")
        case 8:
            result.h264PpsCount += 1
            labels.append("H264_PPS(8)")
        case 5:
            result.h264IdrCount += 1
            labels.append("H264_IDR(5)")
        case 1:
            result.h264NonIdrCount += 1
            labels.append("H264_NON_IDR(1)")
        case 6:
            result.seiCount += 1
            labels.append("H264_SEI(6)")
        default:
            break
        }

        if labels.isEmpty {
            labels.append("HEVC_\(hevcNalType)/H264_\(h264NalType)")
        }

        if result.firstNalTypes.count < 16 {
            result.firstNalTypes.append(labels.joined(separator: " | "))
        }
    }
}

private let alvrDecoderMetadataCollector = ALVRDecoderMetadataCollector()

private let alvrDecoderMetadataCallback: @convention(c) (AlvrVideoFrameData) -> Bool = { frameData in
    alvrDecoderMetadataCollector.record(frameData: frameData)
    return true
}
#endif

@MainActor
final class ALVRClientCoreBridge {
    static let shared = ALVRClientCoreBridge()

    private var isLifecycleSmokeTestRunning = false
    private var isControlledResumeSmokeTestRunning = false
    private var isDecoderMetadataScanRunning = false

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

    func loadClientInfo() -> ALVRClientInfoResult {
        #if canImport(ALVRClientCore)
        var messages = ["ALVRClientCore import available"]
        var didInitialize = false
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

        let serviceType = Self.readCStringFromALVR(bufferSize: 1024) { buffer in
            alvr_mdns_service(buffer)
        }
        messages.append("Read ALVR mDNS service type")

        let rawHostname = Self.readCStringFromALVR(bufferSize: 1024) { buffer in
            alvr_hostname(buffer)
        }
        messages.append("Read ALVR hostname")

        let protocolId = Self.readCStringFromALVR(bufferSize: 1024) { buffer in
            alvr_protocol_id(buffer)
        }
        messages.append("Read ALVR protocol ID")

        alvr_destroy()
        didDestroy = true
        messages.append("Called alvr_destroy()")

        let trimmedHostname = rawHostname.value.isEmpty ? nil : rawHostname.value
        let deviceId = trimmedHostname.map { $0.hasSuffix(".alvr") ? $0 : $0 + ".alvr" }

        if serviceType.wasTruncated {
            messages.append("ALVR mDNS service type may be truncated; returned \(serviceType.returnedLength) bytes for \(serviceType.bufferSize)-byte buffer")
        }
        if rawHostname.wasTruncated {
            messages.append("ALVR hostname may be truncated; returned \(rawHostname.returnedLength) bytes for \(rawHostname.bufferSize)-byte buffer")
        }
        if protocolId.wasTruncated {
            messages.append("ALVR protocol ID may be truncated; returned \(protocolId.returnedLength) bytes for \(protocolId.bufferSize)-byte buffer")
        }

        return ALVRClientInfoResult(
            success: true,
            serviceType: serviceType.value.isEmpty ? nil : serviceType.value.replacingOccurrences(of: ".local", with: ""),
            rawHostname: trimmedHostname,
            deviceId: deviceId,
            protocolId: protocolId.value.isEmpty ? nil : protocolId.value,
            localIPv4Addresses: Self.localIPv4Addresses(),
            messages: messages,
            errorDescription: nil,
            requiresAppRestart: false
        )
        #else
        return ALVRClientInfoResult(
            success: false,
            serviceType: nil,
            rawHostname: nil,
            deviceId: nil,
            protocolId: nil,
            localIPv4Addresses: Self.localIPv4Addresses(),
            messages: ["ALVRClientCore import unavailable"],
            errorDescription: "ALVRClientCore is not available to this target.",
            requiresAppRestart: false
        )
        #endif
    }

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

    func runDecoderMetadataScan(durationMilliseconds: Int = 3000) async -> ALVRDecoderMetadataScanResult {
        guard !isDecoderMetadataScanRunning else {
            return ALVRDecoderMetadataScanResult(
                success: false,
                scanCompleted: false,
                receivedVideoFrames: false,
                messages: ["Decoder metadata scan already running"],
                didInitialize: false,
                didSetDecoderCallback: false,
                didResume: false,
                didPause: false,
                didDestroy: false,
                destroySkipped: false,
                requiresAppRestart: false,
                polledEventCount: 0,
                eventTagNames: [],
                eventTagRawValues: [],
                streamingRelatedEventSeen: false,
                decoderConfigEventSeen: false,
                frameCount: 0,
                totalBytes: 0,
                lastTimestampNs: nil,
                minBufferSize: nil,
                maxBufferSize: nil,
                firstFramePrefixHex: nil,
                lastFramePrefixHex: nil,
                nalScanEnabled: true,
                codecGuess: "unknown",
                nalUnitCount: 0,
                hevcVpsCount: 0,
                hevcSpsCount: 0,
                hevcPpsCount: 0,
                hevcTrailCount: 0,
                hevcNonIdrCount: 0,
                hevcSliceCount: 0,
                hevcIdrCount: 0,
                hevcCraCount: 0,
                h264SpsCount: 0,
                h264PpsCount: 0,
                h264IdrCount: 0,
                h264NonIdrCount: 0,
                seiCount: 0,
                firstNalTypes: [],
                hasParameterSets: false,
                hasIdr: false,
                parameterSetsReady: false,
                videoToolboxReady: false,
                missingDecoderPrerequisites: [],
                noFramesReceivedMessage: nil,
                durationMilliseconds: 0,
                lastStep: "Already running",
                errorDescription: "Decoder metadata scan already running."
            )
        }

        isDecoderMetadataScanRunning = true
        defer { isDecoderMetadataScanRunning = false }

        #if canImport(ALVRClientCore)
        let cappedDurationMilliseconds = min(max(durationMilliseconds, 500), 5000)
        return await Task.detached(priority: .userInitiated) {
            await Self.performDecoderMetadataScan(durationMilliseconds: cappedDurationMilliseconds)
        }.value
        #else
        return ALVRDecoderMetadataScanResult(
            success: false,
            scanCompleted: false,
            receivedVideoFrames: false,
            messages: ["ALVRClientCore import unavailable"],
            didInitialize: false,
            didSetDecoderCallback: false,
            didResume: false,
            didPause: false,
            didDestroy: false,
            destroySkipped: false,
            requiresAppRestart: false,
            polledEventCount: 0,
            eventTagNames: [],
            eventTagRawValues: [],
            streamingRelatedEventSeen: false,
            decoderConfigEventSeen: false,
            frameCount: 0,
            totalBytes: 0,
            lastTimestampNs: nil,
            minBufferSize: nil,
            maxBufferSize: nil,
            firstFramePrefixHex: nil,
            lastFramePrefixHex: nil,
            nalScanEnabled: true,
            codecGuess: "unknown",
            nalUnitCount: 0,
            hevcVpsCount: 0,
            hevcSpsCount: 0,
            hevcPpsCount: 0,
            hevcTrailCount: 0,
            hevcNonIdrCount: 0,
            hevcSliceCount: 0,
            hevcIdrCount: 0,
            hevcCraCount: 0,
            h264SpsCount: 0,
            h264PpsCount: 0,
            h264IdrCount: 0,
            h264NonIdrCount: 0,
            seiCount: 0,
            firstNalTypes: [],
            hasParameterSets: false,
            hasIdr: false,
            parameterSetsReady: false,
            videoToolboxReady: false,
            missingDecoderPrerequisites: [],
            noFramesReceivedMessage: nil,
            durationMilliseconds: 0,
            lastStep: "ALVRClientCore unavailable",
            errorDescription: "ALVRClientCore is not available to this target."
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

    private nonisolated static func performDecoderMetadataScan(durationMilliseconds: Int) async -> ALVRDecoderMetadataScanResult {
        var messages = [
            "ALVRClientCore import available",
            "Metadata-only scan returns true without decoding. This is only for short diagnostics."
        ]
        var didInitialize = false
        var didSetDecoderCallback = false
        var didResume = false
        var didPause = false
        let didDestroy = false
        let destroySkipped = true
        let requiresAppRestart = true
        var eventTagRawValues: [UInt32] = []
        var eventTagNames: [String] = []
        var streamingRelatedEventSeen = false
        var decoderConfigEventSeen = false
        var lastStep = "Not started"
        var didStopCollector = false
        let startDate = Date()
        let deadline = Date().addingTimeInterval(Double(durationMilliseconds) / 1000.0)
        let maxPollIterations = 5000

        func record(_ message: String) {
            lastStep = message
            messages.append(message)
            print("[ALVR Decoder Metadata Scan] \(message)")
        }

        alvrDecoderMetadataCollector.reset()

        defer {
            if didResume && !didPause {
                record("Calling alvr_pause")
                alvr_pause()
                didPause = true
                record("Called alvr_pause() from cleanup")
            }
            if !didStopCollector {
                alvrDecoderMetadataCollector.stop()
            }
        }

        alvrDecoderMetadataCollector.start()

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

        record("Calling alvr_set_decoder_input_callback")
        alvr_set_decoder_input_callback(nil, alvrDecoderMetadataCallback)
        didSetDecoderCallback = true
        record("Called alvr_set_decoder_input_callback(nil, metadataCallback)")

        record("Calling alvr_resume")
        alvr_resume()
        didResume = true
        record("Called alvr_resume()")

        record("Entering limited decoder metadata poll loop for \(durationMilliseconds) ms")
        for _ in 0..<maxPollIterations {
            guard Date() < deadline else {
                break
            }

            var event = AlvrEvent()
            if alvr_poll_event(&event) {
                let rawValue = UInt32(event.tag)
                let tagName = Self.eventTagName(for: rawValue)

                eventTagRawValues.append(rawValue)
                eventTagNames.append(tagName)
                record("Polled event tag: \(tagName) (\(rawValue))")

                if rawValue == UInt32(ALVR_EVENT_STREAMING_STARTED.rawValue)
                    || rawValue == UInt32(ALVR_EVENT_STREAMING_STOPPED.rawValue) {
                    streamingRelatedEventSeen = true
                }
                if rawValue == UInt32(ALVR_EVENT_DECODER_CONFIG.rawValue) {
                    decoderConfigEventSeen = true
                }
            }

            if alvrDecoderMetadataCollector.snapshot().frameCount >= 30 {
                record("Collected 30 decoder metadata frames; stopping scan early")
                break
            }

            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        record("Leaving decoder metadata poll loop")

        record("Calling alvr_pause")
        alvr_pause()
        didPause = true
        record("Called alvr_pause()")

        record("Skipped alvr_destroy() after resume. Restart the app before running another ALVR core test.")

        alvrDecoderMetadataCollector.stop()
        didStopCollector = true
        let snapshot = alvrDecoderMetadataCollector.snapshot()
        messages.append(contentsOf: snapshot.messages)
        let scanCompleted = didInitialize && didSetDecoderCallback && didResume && didPause
        let receivedVideoFrames = snapshot.frameCount > 0
        let noFramesReceivedMessage = receivedVideoFrames ? nil : "No video frames received. The PC ALVR Streamer has not entered the streaming/decoder path yet."
        if let noFramesReceivedMessage {
            messages.append(noFramesReceivedMessage)
        }

        return ALVRDecoderMetadataScanResult(
            success: scanCompleted,
            scanCompleted: scanCompleted,
            receivedVideoFrames: receivedVideoFrames,
            messages: messages,
            didInitialize: didInitialize,
            didSetDecoderCallback: didSetDecoderCallback,
            didResume: didResume,
            didPause: didPause,
            didDestroy: didDestroy,
            destroySkipped: destroySkipped,
            requiresAppRestart: requiresAppRestart,
            polledEventCount: eventTagRawValues.count,
            eventTagNames: eventTagNames,
            eventTagRawValues: eventTagRawValues,
            streamingRelatedEventSeen: streamingRelatedEventSeen,
            decoderConfigEventSeen: decoderConfigEventSeen,
            frameCount: snapshot.frameCount,
            totalBytes: snapshot.totalBytes,
            lastTimestampNs: snapshot.lastTimestampNs,
            minBufferSize: snapshot.minBufferSize,
            maxBufferSize: snapshot.maxBufferSize,
            firstFramePrefixHex: snapshot.firstFramePrefixHex,
            lastFramePrefixHex: snapshot.lastFramePrefixHex,
            nalScanEnabled: snapshot.nalScanEnabled,
            codecGuess: snapshot.codecGuess,
            nalUnitCount: snapshot.nalUnitCount,
            hevcVpsCount: snapshot.hevcVpsCount,
            hevcSpsCount: snapshot.hevcSpsCount,
            hevcPpsCount: snapshot.hevcPpsCount,
            hevcTrailCount: snapshot.hevcTrailCount,
            hevcNonIdrCount: snapshot.hevcNonIdrCount,
            hevcSliceCount: snapshot.hevcSliceCount,
            hevcIdrCount: snapshot.hevcIdrCount,
            hevcCraCount: snapshot.hevcCraCount,
            h264SpsCount: snapshot.h264SpsCount,
            h264PpsCount: snapshot.h264PpsCount,
            h264IdrCount: snapshot.h264IdrCount,
            h264NonIdrCount: snapshot.h264NonIdrCount,
            seiCount: snapshot.seiCount,
            firstNalTypes: snapshot.firstNalTypes,
            hasParameterSets: snapshot.hasParameterSets,
            hasIdr: snapshot.hasIdr,
            parameterSetsReady: snapshot.parameterSetsReady,
            videoToolboxReady: snapshot.videoToolboxReady,
            missingDecoderPrerequisites: snapshot.missingDecoderPrerequisites,
            noFramesReceivedMessage: noFramesReceivedMessage,
            durationMilliseconds: Int(Date().timeIntervalSince(startDate) * 1000),
            lastStep: lastStep,
            errorDescription: nil
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

    private nonisolated static func readCStringFromALVR(bufferSize: Int, _ read: (UnsafeMutablePointer<CChar>?) -> UInt64) -> (value: String, returnedLength: UInt64, bufferSize: Int, wasTruncated: Bool) {
        var buffer = [CChar](repeating: 0, count: bufferSize)
        let returnedLength = buffer.withUnsafeMutableBufferPointer { bufferPointer in
            read(bufferPointer.baseAddress)
        }

        buffer[bufferSize - 1] = 0
        let value = buffer.withUnsafeBufferPointer { bufferPointer in
            String(cString: bufferPointer.baseAddress!)
        }.trimmingCharacters(in: .controlCharacters)

        return (
            value: value,
            returnedLength: returnedLength,
            bufferSize: bufferSize,
            wasTruncated: returnedLength >= UInt64(bufferSize)
        )
    }

    private nonisolated static func localIPv4Addresses() -> [String] {
        var interfaceAddresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaceAddresses) == 0, let firstAddress = interfaceAddresses else {
            return []
        }
        defer { freeifaddrs(interfaceAddresses) }

        var addresses: [String] = []
        var pointer: UnsafeMutablePointer<ifaddrs>? = firstAddress
        while let currentPointer = pointer {
            let interface = currentPointer.pointee
            defer { pointer = interface.ifa_next }

            guard let address = interface.ifa_addr, address.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }

            let flags = Int32(interface.ifa_flags)
            guard (flags & IFF_LOOPBACK) == 0 else {
                continue
            }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                address,
                socklen_t(address.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )

            guard result == 0 else {
                continue
            }

            let ipAddress = String(cString: hostname)
            guard !ipAddress.hasPrefix("127."), !ipAddress.hasPrefix("169.254.") else {
                continue
            }

            addresses.append(ipAddress)
        }

        return Array(Set(addresses)).sorted()
    }
}
