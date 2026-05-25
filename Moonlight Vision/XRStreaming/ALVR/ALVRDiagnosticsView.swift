//
//  ALVRDiagnosticsView.swift
//  Moonlight Vision
//
//  Lightweight diagnostics for the placeholder ALVR session.
//

import SwiftUI

struct ALVRDiagnosticsView: View {
    @EnvironmentObject private var viewModel: MainViewModel
    @ObservedObject private var sessionManager = ALVRSessionManager.shared
    @State private var symbolSmokeResult: SymbolSmokeResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(statusText, systemImage: statusIcon)
                .font(.headline)

            if !sessionManager.hostAddress.isEmpty {
                Text(viewModel.localized("alvr_pc_ip_label") + ": " + sessionManager.hostAddress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !sessionManager.appName.isEmpty {
                Text(viewModel.localized("alvr_app_label") + ": " + sessionManager.appName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .opacity(0.35)

            Button("Run Symbol Smoke Test") {
                symbolSmokeResult = ALVRClientCoreBridge.shared.runSymbolSmokeTest()
            }
            .buttonStyle(.bordered)

            if let symbolSmokeResult {
                Label(
                    symbolSmokeResult.success ? "Symbol smoke test passed" : "Symbol smoke test failed",
                    systemImage: symbolSmokeResult.success ? "checkmark.circle.fill" : "xmark.octagon.fill"
                )
                .font(.caption)

                ForEach(symbolSmokeResult.messages, id: \.self) { message in
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let pathId = symbolSmokeResult.pathId {
                    Text("Path ID: \(pathId)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let errorDescription = symbolSmokeResult.errorDescription {
                    Text(errorDescription)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        // TODO: Migrate ALVR transport, pose input, and controller input diagnostics from alvr-org/alvr-visionos.
    }

    private var statusText: String {
        switch sessionManager.state {
        case .idle:
            return viewModel.localized("alvr_state_idle")
        case .discovering:
            return viewModel.localized("alvr_state_discovering")
        case .pairing:
            return viewModel.localized("alvr_state_pairing")
        case .connecting:
            return viewModel.localized("alvr_state_connecting")
        case .connected:
            return viewModel.localized("alvr_state_connected")
        case .streaming:
            return "ALVR placeholder streaming"
        case .disconnecting:
            return "Disconnecting ALVR"
        case .failed(let message):
            return message
        }
    }

    private var statusIcon: String {
        switch sessionManager.state {
        case .connected, .streaming:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .connecting, .discovering, .pairing, .disconnecting:
            return "arrow.triangle.2.circlepath"
        case .idle:
            return "circle"
        }
    }
}
