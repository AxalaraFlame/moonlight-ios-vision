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
    let fedFrameNalTypes: [String]
    let fedFrameWasRandomAccess: Bool
    let copiedFramePrefixHex: String?
    let convertedLengthPrefixedPrefixHex: String?
    let usedSyntheticPts: Bool
    let samplePtsDescription: String
    let annexBNalCount: Int
    let convertedNalCount: Int
    let convertedSampleSize: Int
    let firstConvertedNalLength: Int?
    let conversionError: String?
    let didWaitForAsynchronousFrames: Bool
    let errorDescription: String?
    let messages: [String]
}

struct ALVRVideoToolboxFrameFeedSummary: Sendable {
    let feedEnabled: Bool
    let copiedFrameCount: Int
    let copiedIdrFrameCount: Int
    let copiedCraFrameCount: Int
    let submittedFrameCount: Int
    let submittedIdrFrameCount: Int
    let submittedCraFrameCount: Int
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
    let fedFrameNalTypes: [String]
    let fedFrameWasRandomAccess: Bool
    let copiedFramePrefixHex: String?
    let convertedLengthPrefixedPrefixHex: String?
    let usedSyntheticPts: Bool
    let samplePtsDescription: String?
    let annexBNalCount: Int
    let convertedNalCount: Int
    let convertedSampleSize: Int
    let firstConvertedNalLength: Int?
    let conversionError: String?
    let didWaitForAsynchronousFrames: Bool
    let decodeErrors: [String]
    let didCallAlvrReportFrameDecoded: Bool
    let messages: [String]
}

final class ALVRVideoToolboxDecoderBridge: @unchecked Sendable {
    private let lock = NSLock()
    private var formatDescription: CMVideoFormatDescription?
    private var decompressionSession: VTDecompressionSession?
    private var latestDecodedPixelBuffer: CVPixelBuffer?
    private var syntheticFrameIndex: Int64 = 0
    private var frameFeedSummary = ALVRVideoToolboxFrameFeedSummary(
        feedEnabled: false,
        copiedFrameCount: 0,
        copiedIdrFrameCount: 0,
        copiedCraFrameCount: 0,
        submittedFrameCount: 0,
        submittedIdrFrameCount: 0,
        submittedCraFrameCount: 0,
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
        fedFrameNalTypes: [],
        fedFrameWasRandomAccess: false,
        copiedFramePrefixHex: nil,
        convertedLengthPrefixedPrefixHex: nil,
        usedSyntheticPts: false,
        samplePtsDescription: nil,
        annexBNalCount: 0,
        convertedNalCount: 0,
        convertedSampleSize: 0,
        firstConvertedNalLength: nil,
        conversionError: nil,
        didWaitForAsynchronousFrames: false,
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
            copiedIdrFrameCount: 0,
            copiedCraFrameCount: 0,
            submittedFrameCount: 0,
            submittedIdrFrameCount: 0,
            submittedCraFrameCount: 0,
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
            fedFrameNalTypes: [],
            fedFrameWasRandomAccess: false,
            copiedFramePrefixHex: nil,
            convertedLengthPrefixedPrefixHex: nil,
            usedSyntheticPts: false,
            samplePtsDescription: nil,
            annexBNalCount: 0,
            convertedNalCount: 0,
            convertedSampleSize: 0,
            firstConvertedNalLength: nil,
            conversionError: nil,
            didWaitForAsynchronousFrames: false,
            decodeErrors: [],
            didCallAlvrReportFrameDecoded: false,
            messages: feedEnabled ? ["HEVC frame feed smoke test enabled; waiting for IDR/CRA frame."] : []
        )
        latestDecodedPixelBuffer = nil
        syntheticFrameIndex = 0
    }

    func frameFeedSummarySnapshot() -> ALVRVideoToolboxFrameFeedSummary {
        lock.lock()
        defer { lock.unlock() }

        return frameFeedSummary
    }

    func feedAnnexBHEVCFrame(_ copiedFrame: ALVRDecoderCopiedFrame) -> ALVRVideoToolboxDecodeResult {
        let session: VTDecompressionSession
        let activeFormatDescription: CMVideoFormatDescription
        let timestampNs = copiedFrame.timestampNs
        let isRandomAccessFrame = copiedFrame.containsIDR || copiedFrame.containsCRA

        lock.lock()
        frameFeedSummary = Self.updatedSummary(frameFeedSummary) { summary in
            summary.copiedFrameCount += 1
            summary.copiedIdrFrameCount += copiedFrame.containsIDR ? 1 : 0
            summary.copiedCraFrameCount += copiedFrame.containsCRA ? 1 : 0
            summary.fedFrameNalTypes = copiedFrame.nalTypes
            summary.fedFrameWasRandomAccess = isRandomAccessFrame
            summary.copiedFramePrefixHex = copiedFrame.prefixHex
            summary.messages.append("Copied HEVC \(isRandomAccessFrame ? "IDR/CRA" : "ordinary") frame for decode smoke test at \(timestampNs).")
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
                fedFrameNalTypes: copiedFrame.nalTypes,
                fedFrameWasRandomAccess: isRandomAccessFrame,
                copiedFramePrefixHex: copiedFrame.prefixHex,
                convertedLengthPrefixedPrefixHex: nil,
                usedSyntheticPts: false,
                samplePtsDescription: "not submitted",
                annexBNalCount: 0,
                convertedNalCount: 0,
                convertedSampleSize: 0,
                firstConvertedNalLength: nil,
                conversionError: nil,
                didWaitForAsynchronousFrames: false,
                errorDescription: error,
                messages: [error]
            )
        }
        session = decompressionSession
        activeFormatDescription = formatDescription
        lock.unlock()

        var messages = ["Converting Annex-B HEVC frame to length-prefixed sample."]
        let conversion: FrameConversionResult
        do {
            conversion = try Self.convertAnnexBToLengthPrefixed(copiedFrame.data)
        } catch {
            let errorDescription = error.localizedDescription
            lock.lock()
            frameFeedSummary = Self.updatedSummary(frameFeedSummary) { summary in
                summary.decodeErrors.append(errorDescription)
                summary.conversionError = errorDescription
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
                fedFrameNalTypes: copiedFrame.nalTypes,
                fedFrameWasRandomAccess: isRandomAccessFrame,
                copiedFramePrefixHex: copiedFrame.prefixHex,
                convertedLengthPrefixedPrefixHex: nil,
                usedSyntheticPts: false,
                samplePtsDescription: "conversion failed",
                annexBNalCount: 0,
                convertedNalCount: 0,
                convertedSampleSize: 0,
                firstConvertedNalLength: nil,
                conversionError: errorDescription,
                didWaitForAsynchronousFrames: false,
                errorDescription: errorDescription,
                messages: messages + [errorDescription]
            )
        }
        messages.append("Converted \(conversion.nalCount) Annex-B NAL units into a \(conversion.data.count)-byte length-prefixed sample.")

        guard !conversion.data.isEmpty else {
            let error = "Converted HEVC sample was empty."
            lock.lock()
            frameFeedSummary = Self.updatedSummary(frameFeedSummary) { summary in
                summary.decodeErrors.append(error)
                summary.conversionError = error
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
                fedFrameNalTypes: copiedFrame.nalTypes,
                fedFrameWasRandomAccess: isRandomAccessFrame,
                copiedFramePrefixHex: copiedFrame.prefixHex,
                convertedLengthPrefixedPrefixHex: nil,
                usedSyntheticPts: false,
                samplePtsDescription: "empty converted sample",
                annexBNalCount: conversion.nalCount,
                convertedNalCount: conversion.nalCount,
                convertedSampleSize: 0,
                firstConvertedNalLength: conversion.firstNalLength,
                conversionError: error,
                didWaitForAsynchronousFrames: false,
                errorDescription: error,
                messages: messages + [error]
            )
        }

        let timing = nextSampleTiming(timestampNs: timestampNs)

        guard let sampleBuffer = Self.createSampleBuffer(
            from: conversion.data,
            formatDescription: activeFormatDescription,
            timing: timing.timing,
            isRandomAccess: isRandomAccessFrame
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
                fedFrameNalTypes: copiedFrame.nalTypes,
                fedFrameWasRandomAccess: isRandomAccessFrame,
                copiedFramePrefixHex: copiedFrame.prefixHex,
                convertedLengthPrefixedPrefixHex: conversion.prefixHex,
                usedSyntheticPts: timing.usedSyntheticPts,
                samplePtsDescription: timing.description,
                annexBNalCount: conversion.nalCount,
                convertedNalCount: conversion.nalCount,
                convertedSampleSize: conversion.data.count,
                firstConvertedNalLength: conversion.firstNalLength,
                conversionError: nil,
                didWaitForAsynchronousFrames: false,
                errorDescription: error,
                messages: messages + [error]
            )
        }
        messages.append("Created CMSampleBuffer for HEVC frame with PTS \(timing.description).")
        messages.append(isRandomAccessFrame ? "Marked sample as sync/random access." : "Marked sample as non-sync ordinary slice.")

        let semaphore = DispatchSemaphore(value: 0)
        let callbackState = DecodeCallbackState()
        var infoFlagsOut = VTDecodeInfoFlags()

        let decodeCallStatus = VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: sampleBuffer,
            flags: VTDecodeFrameFlags(rawValue: 0),
            infoFlagsOut: &infoFlagsOut
        ) { status, infoFlags, imageBuffer, _, _, _ in
            callbackState.record(status: status, infoFlags: infoFlags, imageBuffer: imageBuffer)
            semaphore.signal()
        }

        VTDecompressionSessionWaitForAsynchronousFrames(session)
        messages.append("Called VTDecompressionSessionWaitForAsynchronousFrames.")

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
            summary.submittedIdrFrameCount += decodeCallStatus == noErr && copiedFrame.containsIDR ? 1 : 0
            summary.submittedCraFrameCount += decodeCallStatus == noErr && copiedFrame.containsCRA ? 1 : 0
            summary.decodedFrameCount += success ? 1 : 0
            summary.lastDecodeCallStatus = decodeCallStatus
            summary.lastCallbackStatus = callbackSnapshot.status
            summary.lastInfoFlagsRawValue = callbackSnapshot.infoFlagsRawValue ?? infoFlagsOut.rawValue
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
            summary.fedFrameNalTypes = copiedFrame.nalTypes
            summary.fedFrameWasRandomAccess = isRandomAccessFrame
            summary.copiedFramePrefixHex = copiedFrame.prefixHex
            summary.convertedLengthPrefixedPrefixHex = conversion.prefixHex
            summary.usedSyntheticPts = timing.usedSyntheticPts
            summary.samplePtsDescription = timing.description
            summary.annexBNalCount = conversion.nalCount
            summary.convertedNalCount = conversion.nalCount
            summary.convertedSampleSize = conversion.data.count
            summary.firstConvertedNalLength = conversion.firstNalLength
            summary.conversionError = nil
            summary.didWaitForAsynchronousFrames = true
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
            fedFrameNalTypes: copiedFrame.nalTypes,
            fedFrameWasRandomAccess: isRandomAccessFrame,
            copiedFramePrefixHex: copiedFrame.prefixHex,
            convertedLengthPrefixedPrefixHex: conversion.prefixHex,
            usedSyntheticPts: timing.usedSyntheticPts,
            samplePtsDescription: timing.description,
            annexBNalCount: conversion.nalCount,
            convertedNalCount: conversion.nalCount,
            convertedSampleSize: conversion.data.count,
            firstConvertedNalLength: conversion.firstNalLength,
            conversionError: nil,
            didWaitForAsynchronousFrames: true,
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
        var copiedIdrFrameCount: Int
        var copiedCraFrameCount: Int
        var submittedFrameCount: Int
        var submittedIdrFrameCount: Int
        var submittedCraFrameCount: Int
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
        var fedFrameNalTypes: [String]
        var fedFrameWasRandomAccess: Bool
        var copiedFramePrefixHex: String?
        var convertedLengthPrefixedPrefixHex: String?
        var usedSyntheticPts: Bool
        var samplePtsDescription: String?
        var annexBNalCount: Int
        var convertedNalCount: Int
        var convertedSampleSize: Int
        var firstConvertedNalLength: Int?
        var conversionError: String?
        var didWaitForAsynchronousFrames: Bool
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
            copiedIdrFrameCount: summary.copiedIdrFrameCount,
            copiedCraFrameCount: summary.copiedCraFrameCount,
            submittedFrameCount: summary.submittedFrameCount,
            submittedIdrFrameCount: summary.submittedIdrFrameCount,
            submittedCraFrameCount: summary.submittedCraFrameCount,
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
            fedFrameNalTypes: summary.fedFrameNalTypes,
            fedFrameWasRandomAccess: summary.fedFrameWasRandomAccess,
            copiedFramePrefixHex: summary.copiedFramePrefixHex,
            convertedLengthPrefixedPrefixHex: summary.convertedLengthPrefixedPrefixHex,
            usedSyntheticPts: summary.usedSyntheticPts,
            samplePtsDescription: summary.samplePtsDescription,
            annexBNalCount: summary.annexBNalCount,
            convertedNalCount: summary.convertedNalCount,
            convertedSampleSize: summary.convertedSampleSize,
            firstConvertedNalLength: summary.firstConvertedNalLength,
            conversionError: summary.conversionError,
            didWaitForAsynchronousFrames: summary.didWaitForAsynchronousFrames,
            decodeErrors: summary.decodeErrors,
            didCallAlvrReportFrameDecoded: summary.didCallAlvrReportFrameDecoded,
            messages: summary.messages
        )
        mutate(&mutable)
        return ALVRVideoToolboxFrameFeedSummary(
            feedEnabled: mutable.feedEnabled,
            copiedFrameCount: mutable.copiedFrameCount,
            copiedIdrFrameCount: mutable.copiedIdrFrameCount,
            copiedCraFrameCount: mutable.copiedCraFrameCount,
            submittedFrameCount: mutable.submittedFrameCount,
            submittedIdrFrameCount: mutable.submittedIdrFrameCount,
            submittedCraFrameCount: mutable.submittedCraFrameCount,
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
            fedFrameNalTypes: mutable.fedFrameNalTypes,
            fedFrameWasRandomAccess: mutable.fedFrameWasRandomAccess,
            copiedFramePrefixHex: mutable.copiedFramePrefixHex,
            convertedLengthPrefixedPrefixHex: mutable.convertedLengthPrefixedPrefixHex,
            usedSyntheticPts: mutable.usedSyntheticPts,
            samplePtsDescription: mutable.samplePtsDescription,
            annexBNalCount: mutable.annexBNalCount,
            convertedNalCount: mutable.convertedNalCount,
            convertedSampleSize: mutable.convertedSampleSize,
            firstConvertedNalLength: mutable.firstConvertedNalLength,
            conversionError: mutable.conversionError,
            didWaitForAsynchronousFrames: mutable.didWaitForAsynchronousFrames,
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

    private struct FrameConversionResult {
        let data: Data
        let nalCount: Int
        let firstNalLength: Int?
        let prefixHex: String?
    }

    private struct SampleTimingResult {
        let timing: CMSampleTimingInfo
        let usedSyntheticPts: Bool
        let description: String
    }

    private func nextSampleTiming(timestampNs: UInt64) -> SampleTimingResult {
        if timestampNs > 0 {
            return SampleTimingResult(
                timing: CMSampleTimingInfo(
                    duration: CMTime.invalid,
                    presentationTimeStamp: CMTime(value: CMTimeValue(timestampNs), timescale: 1_000_000_000),
                    decodeTimeStamp: CMTime.invalid
                ),
                usedSyntheticPts: false,
                description: "\(timestampNs) ns"
            )
        }

        lock.lock()
        syntheticFrameIndex += 1
        let frameIndex = syntheticFrameIndex
        lock.unlock()

        return SampleTimingResult(
            timing: CMSampleTimingInfo(
                duration: CMTime.invalid,
                presentationTimeStamp: CMTime(value: frameIndex, timescale: 90),
                decodeTimeStamp: CMTime.invalid
            ),
            usedSyntheticPts: true,
            description: "synthetic frame \(frameIndex) at 90 fps"
        )
    }

    private static func convertAnnexBToLengthPrefixed(_ frameData: Data) throws -> FrameConversionResult {
        let bytes = [UInt8](frameData)
        let ranges = annexBNalRanges(in: bytes)
        guard !ranges.isEmpty else {
            throw FrameConversionError.noNalUnits
        }

        var converted = Data()
        converted.reserveCapacity(frameData.count)
        var firstNalLength: Int?

        for range in ranges {
            let length = UInt32(range.count)
            if firstNalLength == nil {
                firstNalLength = range.count
            }
            converted.append(UInt8((length >> 24) & 0xFF))
            converted.append(UInt8((length >> 16) & 0xFF))
            converted.append(UInt8((length >> 8) & 0xFF))
            converted.append(UInt8(length & 0xFF))
            converted.append(contentsOf: bytes[range])
        }

        return FrameConversionResult(
            data: converted,
            nalCount: ranges.count,
            firstNalLength: firstNalLength,
            prefixHex: prefixHex(for: converted, byteCount: 32)
        )
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
        formatDescription: CMVideoFormatDescription,
        timing: CMSampleTimingInfo,
        isRandomAccess: Bool
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
        var sampleTiming = timing
        var sampleBuffer: CMSampleBuffer?
        status = CMSampleBufferCreateReady(
            allocator: nil,
            dataBuffer: blockBuffer,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &sampleTiming,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        )

        guard status == noErr else {
            return nil
        }

        if let sampleBuffer,
           let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true),
           CFArrayGetCount(attachments) > 0 {
            let attachment = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(
                attachment,
                Unmanaged.passUnretained(kCMSampleAttachmentKey_NotSync).toOpaque(),
                Unmanaged.passUnretained(isRandomAccess ? kCFBooleanFalse : kCFBooleanTrue).toOpaque()
            )
        }

        return sampleBuffer
    }

    private static func prefixHex(for data: Data, byteCount: Int) -> String {
        data.prefix(byteCount).map { String(format: "%02X", $0) }.joined(separator: " ")
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
