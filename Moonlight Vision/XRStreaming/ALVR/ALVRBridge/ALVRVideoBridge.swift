//
//  ALVRVideoBridge.swift
//  Moonlight Vision
//
//  Placeholder for ALVR-specific video decode plumbing.
//

import Foundation

final class ALVRVideoBridge {
    static let shared = ALVRVideoBridge()

    private init() {}

    func configurePlaceholderDecoder() {
        // TODO: Migrate ALVR VideoHandler.swift from alvr-org/alvr-visionos.
        // TODO: Migrate ALVR NALParser.swift from alvr-org/alvr-visionos.
        // TODO: Migrate ALVR AV1Parser.swift from alvr-org/alvr-visionos.
        // TODO: Connect the ALVR decoder callback to VideoToolbox.
        // Do not reuse Moonlight's decoder for VR streaming.
    }
}
