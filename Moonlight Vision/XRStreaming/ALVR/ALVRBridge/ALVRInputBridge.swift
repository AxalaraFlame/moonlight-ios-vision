//
//  ALVRInputBridge.swift
//  Moonlight Vision
//
//  Placeholder for ALVR head pose and controller input.
//

import Foundation

@MainActor
final class ALVRInputBridge {
    static let shared = ALVRInputBridge()

    private(set) var isPlaceholderHeadPoseTrackingRunning = false

    private init() {}

    func startPlaceholderHeadPoseTracking() {
        isPlaceholderHeadPoseTrackingRunning = true
        // TODO: Migrate WorldTracker head pose from alvr-org/alvr-visionos.
        // TODO: Migrate sendTracking from alvr-org/alvr-visionos.
        // TODO: Migrate sendViewParams from alvr-org/alvr-visionos.
        // TODO: Add controller, gesture, and GameController support after head pose works.
    }

    func stopPlaceholderHeadPoseTracking() {
        isPlaceholderHeadPoseTrackingRunning = false
    }
}
