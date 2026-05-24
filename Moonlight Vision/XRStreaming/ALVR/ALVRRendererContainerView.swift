//
//  ALVRRendererContainerView.swift
//  Moonlight Vision
//
//  Placeholder renderer container. Does not use Moonlight flat video rendering.
//

import RealityKit
import SwiftUI

struct ALVRRendererContainerView: View {
    @ObservedObject private var sessionManager = ALVRSessionManager.shared

    var body: some View {
        ZStack {
            RealityView { content in
                let root = Entity()
                root.position = [0, 1.35, -1.6]

                let anchor = ModelEntity(
                    mesh: .generateSphere(radius: 0.08),
                    materials: [SimpleMaterial(color: .green, isMetallic: false)]
                )
                root.addChild(anchor)
                content.add(root)
            }

            VStack(spacing: 8) {
                Text("ALVR Renderer Placeholder")
                    .font(.headline)
                Text("ALVRClientCore linked: \(ALVRClientCoreBridge.shared.isFrameworkAvailable ? "true" : "false")")
                    .font(.caption)
                Text("State: \(sessionManager.state.description)")
                    .font(.caption)
            }
            .padding(18)
            .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        // TODO: Later this container will host an adapted MetalClientSystem / Renderer / CompositorLayer.
        // Do not reuse the Moonlight flat video renderer for VR.
    }
}
