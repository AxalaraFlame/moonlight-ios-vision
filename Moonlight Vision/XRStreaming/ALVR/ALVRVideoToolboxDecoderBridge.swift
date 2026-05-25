//
//  ALVRVideoToolboxDecoderBridge.swift
//  Moonlight Vision
//
//  Minimal VideoToolbox decoder creation diagnostics for ALVR HEVC config.
//

import CoreMedia
import CoreVideo
import Foundation
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

final class ALVRVideoToolboxDecoderBridge {
    private var formatDescription: CMVideoFormatDescription?
    private var decompressionSession: VTDecompressionSession?

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

    func invalidate() {
        if let decompressionSession {
            VTDecompressionSessionInvalidate(decompressionSession)
        }
        decompressionSession = nil
        formatDescription = nil
    }
}
