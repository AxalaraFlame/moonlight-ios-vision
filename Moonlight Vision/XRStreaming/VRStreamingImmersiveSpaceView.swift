//
//  VRStreamingImmersiveSpaceView.swift
//  Moonlight Vision
//
//  Independent VR ImmersiveSpace for CloudXR-backed sessions.
//

import RealityKit
import SwiftUI

struct VRStreamingImmersiveSpaceView: View {
    @EnvironmentObject private var viewModel: MainViewModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow

    @Binding var streamConfig: StreamConfiguration?
    @ObservedObject private var sessionStore = CloudXRSessionStore.shared

    var body: some View {
        ZStack {
            RealityView { content in
                let root = Entity()
                root.position = [0, 1.35, -1.6]

                let marker = ModelEntity(
                    mesh: .generateSphere(radius: 0.08),
                    materials: [SimpleMaterial(color: .cyan, isMetallic: false)]
                )
                root.addChild(marker)
                content.add(root)
            }

            VStack(spacing: 16) {
                Image(systemName: "visionpro")
                    .font(.system(size: 42, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)

                Text(viewModel.localized("vr_streaming_title"))
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(statusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    Task { await closeVRSession() }
                } label: {
                    Label(viewModel.localized("stop"), systemImage: "stop.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            .padding(28)
            .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .task(id: streamConfig?.sessionUUID) {
            await startSessionIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RequestStreamCloseFromMainMenu"))) { _ in
            Task { await closeVRSession(reopenMainWindow: false) }
        }
        .onDisappear {
            streamConfig = nil
        }
    }

    private var statusText: String {
        guard let session = sessionStore.activeSession else {
            return viewModel.localized("vr_streaming_waiting")
        }

        switch session.state {
        case .idle:
            return viewModel.localized("vr_streaming_ready")
        case .connecting:
            return viewModel.localized("vr_streaming_connecting")
        case .streaming:
            return viewModel.localized("vr_streaming_placeholder")
        case .stopped:
            return viewModel.localized("stream_stopped")
        case .failed(let message):
            return message
        }
    }

    @MainActor
    private func startSessionIfNeeded() async {
        guard let session = sessionStore.activeSession else { return }
        await session.start()
        if session.state == .streaming {
            viewModel.streamState = .running
        }
    }

    @MainActor
    private func closeVRSession(reopenMainWindow: Bool = true) async {
        await CloudXRBackend().endSession(viewModel: viewModel)
        await dismissImmersiveSpace()
        if reopenMainWindow {
            openWindow(id: "mainView")
        }
    }
}
