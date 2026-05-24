//
//  ALVRRendererBridge.swift
//  Moonlight Vision
//
//  Placeholder for the ALVR immersive renderer bridge.
//

import Foundation

@MainActor
final class ALVRRendererBridge {
    static let shared = ALVRRendererBridge()

    private(set) var isPlaceholderRendererRunning = false

    private init() {}

    func startPlaceholderRenderer() {
        isPlaceholderRendererRunning = true
        // TODO: Migrate ALVR MetalClientSystem.swift from alvr-org/alvr-visionos.
        // TODO: Migrate ALVR Renderer.swift from alvr-org/alvr-visionos.
        // TODO: Migrate ALVR Shaders.metal from alvr-org/alvr-visionos.
        // TODO: Host the renderer through CompositorServices in ALVRImmersiveSpace.
        // Do not reuse the Moonlight flat renderer for VR streaming.
    }

    func stopPlaceholderRenderer() {
        isPlaceholderRendererRunning = false
    }
}
