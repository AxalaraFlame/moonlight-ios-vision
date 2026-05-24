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
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace

    @ObservedObject private var sessionManager = ALVRSessionManager.shared

    let app: TemporaryApp?

    @State private var pcAddress = ""

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

                    Text(app?.name ?? viewModel.localized("stream_mode_vr"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            TextField(viewModel.localized("alvr_pc_ip_placeholder"), text: $pcAddress)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

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

                Button {
                    Task { await connectVR() }
                } label: {
                    Label(viewModel.localized("alvr_connect_vr"), systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConnecting)
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
    private func connectVR() async {
        guard await sessionManager.connect(to: pcAddress, app: app, viewModel: viewModel) else { return }
        dismiss()
        await openImmersiveSpace(id: "ALVRImmersiveSpace")
    }

    @MainActor
    private func disconnectVR() async {
        await sessionManager.disconnect(viewModel: viewModel)
    }
}
