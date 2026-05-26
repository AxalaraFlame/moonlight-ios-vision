//
//  ALVRImmersiveView.swift
//  Moonlight Vision
//
//  Independent ALVR immersive scene.
//

import SwiftUI

struct ALVRImmersiveView: View {
    @EnvironmentObject private var viewModel: MainViewModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow

    @ObservedObject private var sessionManager = ALVRSessionManager.shared
    @StateObject private var mdnsBroadcaster = ALVRMdnsBroadcaster()
    @StateObject private var sessionDiagnosticsManager = ALVRSessionDiagnosticsManager()

    var body: some View {
        ZStack {
            ALVRRendererContainerView()

            VStack(spacing: 16) {
                Text(viewModel.localized("alvr_immersive_title"))
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(sessionManager.state.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ALVRDiagnosticsView(
                    mdnsBroadcaster: mdnsBroadcaster,
                    sessionDiagnosticsManager: sessionDiagnosticsManager
                )
                    .environmentObject(viewModel)

                Button(role: .destructive) {
                    Task { await close() }
                } label: {
                    Label(viewModel.localized("stop"), systemImage: "stop.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(28)
            .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RequestStreamCloseFromMainMenu"))) { _ in
            Task { await close(reopenMainWindow: false) }
        }
        .task {
            await sessionManager.startPlaceholderStreaming()
        }
        .onDisappear {
            Task {
                await sessionManager.stopPlaceholderStreaming()
            }
        }
    }

    @MainActor
    private func close(reopenMainWindow: Bool = true) async {
        await sessionManager.stopPlaceholderStreaming()
        await sessionManager.disconnect(viewModel: viewModel)
        await dismissImmersiveSpace()
        if reopenMainWindow {
            openWindow(id: "mainView")
        }
    }
}
