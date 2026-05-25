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

    let app: TemporaryApp?

    var body: some View {
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

            ALVRDiagnosticsView()
                .environmentObject(viewModel)

            HStack {
                Button(viewModel.localized("cancel")) {
                    dismiss()
                }
                .buttonStyle(.bordered)

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
        .padding(28)
        .frame(width: 520)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
