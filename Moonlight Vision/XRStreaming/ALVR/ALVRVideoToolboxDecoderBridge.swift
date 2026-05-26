//
//  ALVRVideoToolboxDecoderBridge.swift
//  Moonlight Vision
//
//  Minimal VideoToolbox decoder creation diagnostics for ALVR HEVC config.
//

import CoreMedia
import CoreVideo
import Foundation
import IOSurface
import VideoToolbox

struct ALVRVideoToolboxDecoderCreationResult: Sendable {
    let success: Bool
    let codec: String
    let createdFormatDescription: Bool
    let createdDecompressionSession: Bool
    let formatDescriptionStatus: OSStatus
    let decompressionSessionStatus: OSStatus
    let vpsSize: Int
    let spsSize: Int
    let ppsSize: Int
    let nalUnitHeaderLength: Int
    let errorDescription: String?
    let messages: [String]
}

struct ALVRVideoToolboxDecodeResult: Sendable {
    let success: Bool
    let submitted: Bool
    let decodeCallStatus: OSStatus
    let callbackStatus: OSStatus?
    let infoFlagsRawValue: UInt32?
    let imageBufferReceived: Bool
    let pixelBufferWidth: Int?
    let pixelBufferHeight: Int?
    let pixelFormat: String?
    let planeCount: Int?
    let bytesPerRowByPlane: [Int]
    let hasIOSurface: Bool?
    let isMetalCompatible: Bool?
    let metalCompatibilityHint: String?
    let timestampNs: UInt64
    let errorDescription: String?
    let messages: [String]
}

struct ALVRVideoToolboxFrameFeedSummary: Sendable {
    let feedEnabled: Bool
    let copiedFrameCount: Int
    let submittedFrameCount: Int
    let decodedFrameCount: Int
    let lastDecodeCallStatus: OSStatus?
    let lastCallbackStatus: OSStatus?
    let lastInfoFlagsRawValue: UInt32?
    let lastPixelBufferWidth: Int?
    let lastPixelBufferHeight: Int?
    let lastPixelFormat: String?
    let lastPlaneCount: Int?
    let lastBytesPerRowByPlane: [Int]
    let lastHasIOSurface: Bool?
    let lastIsMetalCompatible: Bool?
    let lastMetalCompatibilityHint: String?
    let hasLatestDecodedPixelBufferSnapshot: Bool
    let lastDecodedTimestampNs: UInt64?
    let decodeErrors: [String]
    let didCallAlvrReportFrameDecoded: Bool
    let messages: [String]
}

final class ALVRVideoToolboxDecoderBridge: @unchecked Sendable {
    private let lock = NSLock()
    private var formatDescription: CMVideoFormatDescription?
    private var decompressionSession: VTDecompressionSession?
    private var latestDecodedPixelBuffer: CVPixelBuffer?
    private var frameFeedSummary = ALVRVideoToolboxFrameFeedSummary(
        feedEnabled: false,
        copiedFrameCount: 0,
        submittedFrameCount: 0,
        decodedFrameCount: 0,
        lastDecodeCallStatus: nil,
        lastCallbackStatus: nil,
        lastInfoFlagsRawValue: nil,
        lastPixelBufferWidth: nil,
        lastPixelBufferHeight: nil,
        lastPixelFormat: nil,
        lastPlaneCount: nil,
        lastBytesPerRowByPlane: [],
        lastHasIOSurface: nil,
        lastIsMetalCompatible: nil,
        lastMetalCompatibilityHint: nil,
        hasLatestDecodedPixelBufferSnapshot: false,
        lastDecodedTimestampNs: nil,
        decodeErrors: [],
        didCallAlvrReportFrameDecoded: false,
        messages: []
    )

    deinit {
        invalidate()
    }

    func createHEVCDecoderSkeleton(
        vps: [UInt8],
        sps: [UInt8],
        pps: [UInt8]
    ) -> ALVRVideoToolboxDecoderCreationResult {
        invalidate()

        let nalUnitHeaderLength: Int32 = 4
        var messages = [
            "Creating HEVC CMVideoFormatDescription from VPS/SPS/PPS.",
            "This only creates the VideoToolbox decoder session. It does not feed frames or render SteamVR."
        ]

        guard !vps.isEmpty, !sps.isEmpty, !pps.isEmpty else {
            return ALVRVideoToolboxDecoderCreationResult(
                success: false,
                codec: "hevc",
                createdFormatDescription: false,
                createdDecompressionSession: false,
                formatDescriptionStatus: -1,
                decompressionSessionStatus: -1,
                vpsSize: vps.count,
                spsSize: sps.count,
                ppsSize: pps.count,
                nalUnitHeaderLength: Int(nalUnitHeaderLength),
                errorDescription: "HEVC VPS/SPS/PPS must all be present before creating a VideoToolbox decoder.",
                messages: messages
            )
        }

        var createdFormatDescription: CMVideoFormatDescription?
        let formatStatus = vps.withUnsafeBufferPointer { vpsPointer in
            sps.withUnsafeBufferPointer { spsPointer in
                pps.withUnsafeBufferPointer { ppsPointer in
                    guard let vpsBaseAddress = vpsPointer.baseAddress,
                          let spsBaseAddress = spsPointer.baseAddress,
                          let ppsBaseAddress = ppsPointer.baseAddress else {
                        return OSStatus(-1)
                    }

                    let parameterSetPointers = [
                        vpsBaseAddress,
                        spsBaseAddress,
                        ppsBaseAddress
                    ]
                    let parameterSetSizes = [
                        vps.count,
                        sps.count,
                        pps.count
                    ]

                    return parameterSetPointers.withUnsafeBufferPointer { pointerBuffer in
                        parameterSetSizes.withUnsafeBufferPointer { sizeBuffer in
                            guard let pointerBaseAddress = pointerBuffer.baseAddress,
                                  let sizeBaseAddress = sizeBuffer.baseAddress else {
                                return OSStatus(-1)
                            }

                            return CMVideoFormatDescriptionCreateFromHEVCParameterSets(
                                allocator: nil,
                                parameterSetCount: 3,
                                parameterSetPointers: pointerBaseAddress,
                                parameterSetSizes: sizeBaseAddress,
                                nalUnitHeaderLength: nalUnitHeaderLength,
                                extensions: nil,
                                formatDescriptionOut: &createdFormatDescription
                            )
                        }
                    }
                }
            }
        }

        guard formatStatus == noErr, let createdFormatDescription else {
            messages.append("CMVideoFormatDescriptionCreateFromHEVCParameterSets failed with status \(formatStatus).")
            return ALVRVideoToolboxDecoderCreationResult(
                success: false,
                codec: "hevc",
                createdFormatDescription: false,
                createdDecompressionSession: false,
                formatDescriptionStatus: formatStatus,
                decompressionSessionStatus: -1,
                vpsSize: vps.count,
                spsSize: sps.count,
                ppsSize: pps.count,
                nalUnitHeaderLength: Int(nalUnitHeaderLength),
                errorDescription: "Failed to create HEVC CMVideoFormatDescription.",
                messages: messages
            )
        }

        messages.append("Created HEVC CMVideoFormatDescription.")

        let decoderSpecification: [NSString: AnyObject] = [
            kVTVideoDecoderSpecification_EnableHardwareAcceleratedVideoDecoder: kCFBooleanTrue
        ]
        let imageBufferAttributes: [NSString: AnyObject] = [
            kCVPixelBufferMetalCompatibilityKey: true as NSNumber,
            kCVPixelBufferPoolMinimumBufferCountKey: 3 as NSNumber
        ]

        var createdSession: VTDecompressionSession?
        let sessionStatus = VTDecompressionSessionCreate(
            allocator: nil,
            formatDescription: createdFormatDescription,
            decoderSpecification: decoderSpecification as CFDictionary,
            imageBufferAttributes: imageBufferAttributes as CFDictionary,
            outputCallback: nil,
            decompressionSessionOut: &createdSession
        )

        guard sessionStatus == noErr, let createdSession else {
            messages.append("VTDecompressionSessionCreate failed with status \(sessionStatus).")
            return ALVRVideoToolboxDecoderCreationResult(
                success: false,
                codec: "hevc",
                createdFormatDescription: true,
                createdDecompressionSession: false,
                formatDescriptionStatus: formatStatus,
                decompressionSessionStatus: sessionStatus,
                vpsSize: vps.count,
                spsSize: sps.count,
                ppsSize: pps.count,
                nalUnitHeaderLength: Int(nalUnitHeaderLength),
                errorDescription: "Failed to create HEVC VTDecompressionSession.",
                messages: messages
            )
        }

        formatDescription = createdFormatDescription
        decompressionSession = createdSession
        messages.append("Created HEVC VTDecompressionSession.")
        messages.append("No video frames were fed to VideoToolbox.")

        return ALVRVideoToolboxDecoderCreationResult(
            success: true,
            codec: "hevc",
            createdFormatDescription: true,
            createdDecompressionSession: true,
            formatDescriptionStatus: formatStatus,
            decompressionSessionStatus: sessionStatus,
            vpsSize: vps.count,
            spsSize: sps.count,
            ppsSize: pps.count,
            nalUnitHeaderLength: Int(nalUnitHeaderLength),
            errorDescription: nil,
            messages: messages
        )
    }

    func resetFrameFeedSummary(feedEnabled: Bool) {
        lock.lock()
        defer { lock.unlock() }

        frameFeedSummary = ALVRVideoToolboxFrameFeedSummary(
            feedEnabled: feedEnabled,
            copiedFrameCount: 0,
            submittedFrameCount: 0,
            decodedFrameCount: 0,
            lastDecodeCallStatus: nil,
            lastCallbackStatus: nil,
            lastInfoFlagsRawValue: nil,
            lastPixelBufferWidth: nil,
            lastPixelBufferHeight: nil,
            lastPixelFormat: nil,
            lastPlaneCount: nil,
            lastBytesPerRowByPlane: [],
            lastHasIOSurface: nil,
            lastIsMetalCompatible: nil,
            lastMetalCompatibilityHint: nil,
            hasLatestDecodedPixelBufferSnapshot: false,
            lastDecodedTimestampNs: nil,
            decodeErrors: [],
            didCallAlvrReportFrameDecoded: false,
            messages: feedEnabled ? ["HEVC frame feed smoke test enabled."] : []
        )
        latestDecodedPixelBuffer = nil
    }

    func frameFeedSummarySnapshot() -> ALVRVideoToolboxFrameFeedSummary {
        lock.lock()
        defer { lock.unlock() }

        return frameFeedSummary
    }

    func feedAnnexBHEVCFrame(_ frameData: Data, timestampNs: UInt64) -> ALVRVideoToolboxDecodeResult {
        let session: VTDecompressionSession
        let activeFormatDescription: CMVideoFormatDescription

        lock.lock()
        frameFeedSummary = Self.updatedSummary(frameFeedSummary) { summary in
            summary.copiedFrameCount += 1
            summary.messages.append("Copied HEVC frame for decode smoke test at \(timestampNs).")
        }
        guard let decompressionSession, let formatDescription else {
            let error = "HEVC VTDecompressionSession is not available."
            frameFeedSummary = Self.updatedSummary(frameFeedSummary) { summary in
                summary.decodeErrors.append(error)
            }
            lock.unlock()
            return ALVRVideoToolboxDecodeResult(
                success: false,
                submitted: false,
                decodeCallStatus: -1,
                callbackStatus: nil,
                infoFlagsRawValue: nil,
                imageBufferReceived: false,
                pixelBufferWidth: nil,
                pixelBufferHeight: nil,
                pixelFormat: nil,
                planeCount: nil,
                bytesPerRowByPlane: [],
                hasIOSurface: nil,
                isMetalCompatible: nil,
                metalCompatibilityHint: nil,
                timestampNs: timestampNs,
                errorDescription: error,
                messages: [error]
            )
        }
        session = decompressionSession
        activeFormatDescription = formatDescription
        lock.unlock()

        var messages = ["Converting Annex-B HEVC frame to length-prefixed sample."]
        let convertedFrame: Data
        do {
            convertedFrame = try Self.convertAnnexBToLengthPrefixed(frameData)
        } catch {
            let errorDescription = error.localizedDescription
            lock.lock()
            frameFeedSummary = Self.updatedSummary(frameFeedSummary) { summary in
                summary.decodeErrors.append(errorDescription)
            }
            lock.unlock()
            return ALVRVideoToolboxDecodeResult(
                success: false,
                submitted: false,
                decodeCallStatus: -1,
                callbackStatus: nil,
                infoFlagsRawValue: nil,
                imageBufferReceived: false,
                pixelBufferWidth: nil,
                pixelBufferHeight: nil,
                pixelFormat: nil,
                planeCount: nil,
                bytesPerRowByPlane: [],
                hasIOSurface: nil,
                isMetalCompatible: nil,
                metalCompatibilityHint: nil,
                timestampNs: timestampNs,
                errorDescription: errorDescription,
                messages: messages + [errorDescription]
            )
        }

        guard let sampleBuffer = Self.createSampleBuffer(
            from: convertedFrame,
            formatDescription: activeFormatDescription
        ) else {
            let error = "Failed to create CMSampleBuffer for HEVC frame."
            lock.lock()
            frameFeedSummary = Self.updatedSummary(frameFeedSummary) { summary in
                summary.decodeErrors.append(error)
            }
            lock.unlock()
            return ALVRVideoToolboxDecodeResult(
                success: false,
                submitted: false,
                decodeCallStatus: -1,
                callbackStatus: nil,
                infoFlagsRawValue: nil,
                imageBufferReceived: false,
                pixelBufferWidth: nil,
                pixelBufferHeight: nil,
                pixelFormat: nil,
                planeCount: nil,
                bytesPerRowByPlane: [],
                hasIOSurface: nil,
                isMetalCompatible: nil,
                metalCompatibilityHint: nil,
                timestampNs: timestampNs,
                errorDescription: error,
                messages: messages + [error]
            )
        }
        messages.append("Created CMSampleBuffer for HEVC frame.")

        let semaphore = DispatchSemaphore(value: 0)
        let callbackState = DecodeCallbackState()

        let decodeCallStatus = VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: sampleBuffer,
            flags: VTDecodeFrameFlags(rawValue: 0),
            infoFlagsOut: nil
        ) { status, infoFlags, imageBuffer, _, _, _ in
            callbackState.record(status: status, infoFlags: infoFlags, imageBuffer: imageBuffer)
            semaphore.signal()
        }

        let didReceiveCallback = semaphore.wait(timeout: .now() + .milliseconds(250)) == .success
        let callbackSnapshot = callbackState.snapshot()

        if !didReceiveCallback {
            messages.append("Decode callback did not fire within 250 ms.")
        }

        let success = decodeCallStatus == noErr && callbackSnapshot.status == noErr && callbackSnapshot.imageBufferReceived
        let errorDescription: String?
        if success {
            errorDescription = nil
            messages.append("VideoToolbox returned a CVPixelBuffer.")
        } else {
            errorDescription = "HEVC decode smoke test did not produce a CVPixelBuffer."
        }

        lock.lock()
        frameFeedSummary = Self.updatedSummary(frameFeedSummary) { summary in
            summary.submittedFrameCount += decodeCallStatus == noErr ? 1 : 0
            summary.decodedFrameCount += success ? 1 : 0
            summary.lastDecodeCallStatus = decodeCallStatus
            summary.lastCallbackStatus = callbackSnapshot.status
            summary.lastInfoFlagsRawValue = callbackSnapshot.infoFlagsRawValue
            summary.lastPixelBufferWidth = callbackSnapshot.pixelBufferWidth
            summary.lastPixelBufferHeight = callbackSnapshot.pixelBufferHeight
            summary.lastPixelFormat = callbackSnapshot.pixelFormat
            summary.lastPlaneCount = callbackSnapshot.planeCount
            summary.lastBytesPerRowByPlane = callbackSnapshot.bytesPerRowByPlane
            summary.lastHasIOSurface = callbackSnapshot.hasIOSurface
            summary.lastIsMetalCompatible = callbackSnapshot.isMetalCompatible
            summary.lastMetalCompatibilityHint = callbackSnapshot.metalCompatibilityHint
            summary.hasLatestDecodedPixelBufferSnapshot = success && callbackSnapshot.latestDecodedPixelBuffer != nil
            summary.lastDecodedTimestampNs = success ? timestampNs : summary.lastDecodedTimestampNs
            summary.messages.append(contentsOf: messages)
            if let errorDescription {
                summary.decodeErrors.append(errorDescription)
            }
        }
        if success {
            latestDecodedPixelBuffer = callbackSnapshot.latestDecodedPixelBuffer
        }
        lock.unlock()

        return ALVRVideoToolboxDecodeResult(
            success: success,
            submitted: decodeCallStatus == noErr,
            decodeCallStatus: decodeCallStatus,
            callbackStatus: callbackSnapshot.status,
            infoFlagsRawValue: callbackSnapshot.infoFlagsRawValue,
            imageBufferReceived: callbackSnapshot.imageBufferReceived,
            pixelBufferWidth: callbackSnapshot.pixelBufferWidth,
            pixelBufferHeight: callbackSnapshot.pixelBufferHeight,
            pixelFormat: callbackSnapshot.pixelFormat,
            planeCount: callbackSnapshot.planeCount,
            bytesPerRowByPlane: callbackSnapshot.bytesPerRowByPlane,
            hasIOSurface: callbackSnapshot.hasIOSurface,
            isMetalCompatible: callbackSnapshot.isMetalCompatible,
            metalCompatibilityHint: callbackSnapshot.metalCompatibilityHint,
            timestampNs: timestampNs,
            errorDescription: errorDescription,
            messages: messages
        )
    }

    func invalidate() {
        lock.lock()
        defer { lock.unlock() }

        if let decompressionSession {
            VTDecompressionSessionInvalidate(decompressionSession)
        }
        decompressionSession = nil
        formatDescription = nil
        latestDecodedPixelBuffer = nil
        frameFeedSummary = Self.updatedSummary(frameFeedSummary) { summary in
            summary.feedEnabled = false
            summary.hasLatestDecodedPixelBufferSnapshot = false
        }
    }

    private struct MutableFrameFeedSummary {
        var feedEnabled: Bool
        var copiedFrameCount: Int
        var submittedFrameCount: Int
        var decodedFrameCount: Int
        var lastDecodeCallStatus: OSStatus?
        var lastCallbackStatus: OSStatus?
        var lastInfoFlagsRawValue: UInt32?
        var lastPixelBufferWidth: Int?
        var lastPixelBufferHeight: Int?
        var lastPixelFormat: String?
        var lastPlaneCount: Int?
        var lastBytesPerRowByPlane: [Int]
        var lastHasIOSurface: Bool?
        var lastIsMetalCompatible: Bool?
        var lastMetalCompatibilityHint: String?
        var hasLatestDecodedPixelBufferSnapshot: Bool
        var lastDecodedTimestampNs: UInt64?
        var decodeErrors: [String]
        var didCallAlvrReportFrameDecoded: Bool
        var messages: [String]
    }

    private struct DecodeCallbackSnapshot {
        let status: OSStatus?
        let infoFlagsRawValue: UInt32?
        let imageBufferReceived: Bool
        let pixelBufferWidth: Int?
        let pixelBufferHeight: Int?
        let pixelFormat: String?
        let planeCount: Int?
        let bytesPerRowByPlane: [Int]
        let hasIOSurface: Bool?
        let isMetalCompatible: Bool?
        let metalCompatibilityHint: String?
        let latestDecodedPixelBuffer: CVPixelBuffer?
    }

    private final class DecodeCallbackState: @unchecked Sendable {
        private let lock = NSLock()
        private var status: OSStatus?
        private var infoFlagsRawValue: UInt32?
        private var imageBufferReceived = false
        private var pixelBufferWidth: Int?
        private var pixelBufferHeight: Int?
        private var pixelFormat: String?
        private var planeCount: Int?
        private var bytesPerRowByPlane: [Int] = []
        private var hasIOSurface: Bool?
        private var isMetalCompatible: Bool?
        private var metalCompatibilityHint: String?
        private var latestDecodedPixelBuffer: CVPixelBuffer?

        func record(status: OSStatus, infoFlags: VTDecodeInfoFlags, imageBuffer: CVImageBuffer?) {
            lock.lock()
            defer { lock.unlock() }

            self.status = status
            infoFlagsRawValue = infoFlags.rawValue
            if let imageBuffer {
                imageBufferReceived = true
                pixelBufferWidth = CVPixelBufferGetWidth(imageBuffer)
                pixelBufferHeight = CVPixelBufferGetHeight(imageBuffer)
                pixelFormat = ALVRVideoToolboxDecoderBridge.pixelFormatDescription(CVPixelBufferGetPixelFormatType(imageBuffer))
                planeCount = CVPixelBufferGetPlaneCount(imageBuffer)
                bytesPerRowByPlane = ALVRVideoToolboxDecoderBridge.bytesPerRowByPlane(for: imageBuffer)
                hasIOSurface = CVPixelBufferGetIOSurface(imageBuffer) != nil
                isMetalCompatible = ALVRVideoToolboxDecoderBridge.metalCompatibilityAttachment(for: imageBuffer)
                metalCompatibilityHint = ALVRVideoToolboxDecoderBridge.metalCompatibilityHint(
                    isMetalCompatible: isMetalCompatible,
                    hasIOSurface: hasIOSurface
                )
                latestDecodedPixelBuffer = imageBuffer
            }
        }

        func snapshot() -> DecodeCallbackSnapshot {
            lock.lock()
            defer { lock.unlock() }

            return DecodeCallbackSnapshot(
                status: status,
                infoFlagsRawValue: infoFlagsRawValue,
                imageBufferReceived: imageBufferReceived,
                pixelBufferWidth: pixelBufferWidth,
                pixelBufferHeight: pixelBufferHeight,
                pixelFormat: pixelFormat,
                planeCount: planeCount,
                bytesPerRowByPlane: bytesPerRowByPlane,
                hasIOSurface: hasIOSurface,
                isMetalCompatible: isMetalCompatible,
                metalCompatibilityHint: metalCompatibilityHint,
                latestDecodedPixelBuffer: latestDecodedPixelBuffer
            )
        }
    }

    private static func updatedSummary(
        _ summary: ALVRVideoToolboxFrameFeedSummary,
        mutate: (inout MutableFrameFeedSummary) -> Void
    ) -> ALVRVideoToolboxFrameFeedSummary {
        var mutable = MutableFrameFeedSummary(
            feedEnabled: summary.feedEnabled,
            copiedFrameCount: summary.copiedFrameCount,
            submittedFrameCount: summary.submittedFrameCount,
            decodedFrameCount: summary.decodedFrameCount,
            lastDecodeCallStatus: summary.lastDecodeCallStatus,
            lastCallbackStatus: summary.lastCallbackStatus,
            lastInfoFlagsRawValue: summary.lastInfoFlagsRawValue,
            lastPixelBufferWidth: summary.lastPixelBufferWidth,
            lastPixelBufferHeight: summary.lastPixelBufferHeight,
            lastPixelFormat: summary.lastPixelFormat,
            lastPlaneCount: summary.lastPlaneCount,
            lastBytesPerRowByPlane: summary.lastBytesPerRowByPlane,
            lastHasIOSurface: summary.lastHasIOSurface,
            lastIsMetalCompatible: summary.lastIsMetalCompatible,
            lastMetalCompatibilityHint: summary.lastMetalCompatibilityHint,
            hasLatestDecodedPixelBufferSnapshot: summary.hasLatestDecodedPixelBufferSnapshot,
            lastDecodedTimestampNs: summary.lastDecodedTimestampNs,
            decodeErrors: summary.decodeErrors,
            didCallAlvrReportFrameDecoded: summary.didCallAlvrReportFrameDecoded,
            messages: summary.messages
        )
        mutate(&mutable)
        return ALVRVideoToolboxFrameFeedSummary(
            feedEnabled: mutable.feedEnabled,
            copiedFrameCount: mutable.copiedFrameCount,
            submittedFrameCount: mutable.submittedFrameCount,
            decodedFrameCount: mutable.decodedFrameCount,
            lastDecodeCallStatus: mutable.lastDecodeCallStatus,
            lastCallbackStatus: mutable.lastCallbackStatus,
            lastInfoFlagsRawValue: mutable.lastInfoFlagsRawValue,
            lastPixelBufferWidth: mutable.lastPixelBufferWidth,
            lastPixelBufferHeight: mutable.lastPixelBufferHeight,
            lastPixelFormat: mutable.lastPixelFormat,
            lastPlaneCount: mutable.lastPlaneCount,
            lastBytesPerRowByPlane: mutable.lastBytesPerRowByPlane,
            lastHasIOSurface: mutable.lastHasIOSurface,
            lastIsMetalCompatible: mutable.lastIsMetalCompatible,
            lastMetalCompatibilityHint: mutable.lastMetalCompatibilityHint,
            hasLatestDecodedPixelBufferSnapshot: mutable.hasLatestDecodedPixelBufferSnapshot,
            lastDecodedTimestampNs: mutable.lastDecodedTimestampNs,
            decodeErrors: mutable.decodeErrors,
            didCallAlvrReportFrameDecoded: mutable.didCallAlvrReportFrameDecoded,
            messages: mutable.messages
        )
    }

    private enum FrameConversionError: LocalizedError {
        case noNalUnits

        var errorDescription: String? {
            switch self {
            case .noNalUnits:
                return "No Annex-B NAL units found in HEVC frame."
            }
        }
    }

    private static func convertAnnexBToLengthPrefixed(_ frameData: Data) throws -> Data {
        let bytes = [UInt8](frameData)
        let ranges = annexBNalRanges(in: bytes)
        guard !ranges.isEmpty else {
            throw FrameConversionError.noNalUnits
        }

        var converted = Data()
        converted.reserveCapacity(frameData.count)

        for range in ranges {
            let length = UInt32(range.count)
            converted.append(UInt8((length >> 24) & 0xFF))
            converted.append(UInt8((length >> 16) & 0xFF))
            converted.append(UInt8((length >> 8) & 0xFF))
            converted.append(UInt8(length & 0xFF))
            converted.append(contentsOf: bytes[range])
        }

        return converted
    }

    private static func annexBNalRanges(in bytes: [UInt8]) -> [Range<Int>] {
        var starts: [(startCodeIndex: Int, payloadIndex: Int)] = []
        var index = 0

        while index + 3 <= bytes.count {
            if bytes[index] == 0,
               bytes[index + 1] == 0,
               bytes[index + 2] == 1 {
                starts.append((index, index + 3))
                index += 3
            } else if index + 4 <= bytes.count,
                      bytes[index] == 0,
                      bytes[index + 1] == 0,
                      bytes[index + 2] == 0,
                      bytes[index + 3] == 1 {
                starts.append((index, index + 4))
                index += 4
            } else {
                index += 1
            }
        }

        var ranges: [Range<Int>] = []
        for startIndex in starts.indices {
            let payloadStart = starts[startIndex].payloadIndex
            let payloadEnd = startIndex + 1 < starts.count ? starts[startIndex + 1].startCodeIndex : bytes.count
            if payloadStart < payloadEnd {
                ranges.append(payloadStart..<payloadEnd)
            }
        }
        return ranges
    }

    private static func createSampleBuffer(
        from convertedFrame: Data,
        formatDescription: CMVideoFormatDescription
    ) -> CMSampleBuffer? {
        var blockBuffer: CMBlockBuffer?
        var status = CMBlockBufferCreateWithMemoryBlock(
            allocator: nil,
            memoryBlock: nil,
            blockLength: convertedFrame.count,
            blockAllocator: nil,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: convertedFrame.count,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        guard status == noErr, let blockBuffer else {
            return nil
        }

        status = convertedFrame.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                return OSStatus(-1)
            }
            return CMBlockBufferReplaceDataBytes(
                with: baseAddress,
                blockBuffer: blockBuffer,
                offsetIntoDestination: 0,
                dataLength: convertedFrame.count
            )
        }

        guard status == noErr else {
            return nil
        }

        var sampleSize = convertedFrame.count
        var sampleBuffer: CMSampleBuffer?
        status = CMSampleBufferCreateReady(
            allocator: nil,
            dataBuffer: blockBuffer,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 0,
            sampleTimingArray: nil,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        )

        guard status == noErr else {
            return nil
        }

        return sampleBuffer
    }

    private static func pixelFormatDescription(_ pixelFormat: OSType) -> String {
        var bigEndian = pixelFormat.bigEndian
        let fourCC = withUnsafeBytes(of: &bigEndian) { rawBuffer -> String in
            let scalars = rawBuffer.map { byte -> UnicodeScalar in
                if byte >= 32 && byte <= 126 {
                    return UnicodeScalar(Int(byte))!
                }
                return "."
            }
            return String(String.UnicodeScalarView(scalars))
        }
        return "\(fourCC) (\(pixelFormat))"
    }

    private static func bytesPerRowByPlane(for pixelBuffer: CVPixelBuffer) -> [Int] {
        let planeCount = CVPixelBufferGetPlaneCount(pixelBuffer)
        guard planeCount > 0 else {
            return [CVPixelBufferGetBytesPerRow(pixelBuffer)]
        }

        return (0..<planeCount).map { planeIndex in
            CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, planeIndex)
        }
    }

    private static func metalCompatibilityAttachment(for pixelBuffer: CVPixelBuffer) -> Bool? {
        guard let attachment = CVBufferCopyAttachment(pixelBuffer, kCVPixelBufferMetalCompatibilityKey, nil) else {
            return nil
        }

        return (attachment as? NSNumber)?.boolValue
    }

    private static func metalCompatibilityHint(isMetalCompatible: Bool?, hasIOSurface: Bool?) -> String? {
        if isMetalCompatible == true {
            return "Pixel buffer reports Metal compatibility."
        }

        if isMetalCompatible == false {
            return "Pixel buffer reports it is not Metal compatible."
        }

        if hasIOSurface == true {
            return "Metal compatibility attachment is unavailable; IOSurface is present and Metal compatibility was requested."
        }

        if hasIOSurface == false {
            return "Metal compatibility attachment is unavailable and no IOSurface was reported."
        }

        return "Metal compatibility attachment is unavailable."
    }
}
