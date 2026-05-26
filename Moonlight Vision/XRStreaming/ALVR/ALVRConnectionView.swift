//
//  ALVRConnectionView.swift
//  Moonlight Vision
//
//  Manual ALVR connection entry point.
//

import SwiftUI

struct ALVRConnectionView: View {
    @EnvironmentObject private var viewModel: MainViewModel
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var sessionManager = ALVRSessionManager.shared
    @ObservedObject private var mdnsBroadcaster: ALVRMdnsBroadcaster
    @ObservedObject private var sessionDiagnosticsManager: ALVRSessionDiagnosticsManager

    let app: TemporaryApp?
    let showsDismissButton: Bool

    init(
        app: TemporaryApp?,
        showsDismissButton: Bool = true,
        mdnsBroadcaster: ALVRMdnsBroadcaster,
        sessionDiagnosticsManager: ALVRSessionDiagnosticsManager
    ) {
        self.app = app
        self.showsDismissButton = showsDismissButton
        self.mdnsBroadcaster = mdnsBroadcaster
        self.sessionDiagnosticsManager = sessionDiagnosticsManager
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 28) {
                    connectionPanel
                        .frame(minWidth: 280, maxWidth: 360, alignment: .topLeading)

                    diagnosticsPanel
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }

                VStack(alignment: .leading, spacing: 20) {
                    connectionPanel
                    diagnosticsPanel
                }
            }
            .padding(.vertical, 8)
            .padding(.bottom, 64)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.visible)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var connectionPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(systemName: "visionpro")
                    .font(.system(size: 34, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)

                VStack(alignment: .leading, spacing: 4) {
                    Text("ALVR / SteamVR")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("PCVR Headset Client")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Text("ALVR connects from the PC side. Open ALVR Streamer on your PC and add or discover this Vision Pro headset.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if let error = sessionManager.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                if showsDismissButton {
                    Button(viewModel.localized("cancel")) {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    Task { await disconnectVR() }
                } label: {
                    Label("Disconnect", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
                .disabled(!sessionManager.isConnected && !isConnecting)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var diagnosticsPanel: some View {
        ALVRDiagnosticsView(
            mdnsBroadcaster: mdnsBroadcaster,
            sessionDiagnosticsManager: sessionDiagnosticsManager
        )
            .environmentObject(viewModel)
    }

    private var isConnecting: Bool {
        if case .connecting = sessionManager.state { return true }
        return false
    }

    @MainActor
    private func disconnectVR() async {
        await sessionManager.disconnect(viewModel: viewModel)
    }
}
