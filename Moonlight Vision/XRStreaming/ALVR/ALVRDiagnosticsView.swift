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
    @StateObject private var mdnsBroadcaster = ALVRMdnsBroadcaster()
    @State private var symbolSmokeResult: SymbolSmokeResult?
    @State private var lifecycleSmokeResult: LifecycleSmokeResult?
    @State private var controlledResumeSmokeResult: ControlledResumeSmokeResult?
    @State private var clientInfoResult: ALVRClientInfoResult?
    @State private var decoderMetadataScanResult: ALVRDecoderMetadataScanResult?
    @State private var isControlledResumeSmokeTestRunning = false
    @State private var isDecoderMetadataScanRunning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(statusText, systemImage: statusIcon)
                .font(.headline)

            if !sessionManager.appName.isEmpty {
                Text(viewModel.localized("alvr_app_label") + ": " + sessionManager.appName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("ALVR connects from the PC side. Open ALVR Streamer on your PC and add or discover this Vision Pro headset.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Load ALVR Client Info") {
                guard !coreTestsRequireRestart else {
                    clientInfoResult = ALVRClientInfoResult(
                        success: false,
                        serviceType: nil,
                        rawHostname: nil,
                        deviceId: nil,
                        protocolId: nil,
                        localIPv4Addresses: [],
                        messages: ["Restart the app before running another ALVR core test."],
                        errorDescription: "ALVR core was resumed in this app process.",
                        requiresAppRestart: true
                    )
                    return
                }

                clientInfoResult = ALVRClientCoreBridge.shared.loadClientInfo()
            }
            .buttonStyle(.bordered)
            .disabled(coreTestsRequireRestart)

            if let clientInfoResult {
                Label(
                    clientInfoResult.success ? "ALVR client info loaded" : "ALVR client info unavailable",
                    systemImage: clientInfoResult.success ? "checkmark.circle.fill" : "xmark.octagon.fill"
                )
                .font(.caption)

                if let serviceType = clientInfoResult.serviceType {
                    Text("Service type: \(serviceType)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let rawHostname = clientInfoResult.rawHostname {
                    Text("Hostname: \(rawHostname)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let deviceId = clientInfoResult.deviceId {
                    Text("Device ID: \(deviceId)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let protocolId = clientInfoResult.protocolId {
                    Text("Protocol ID: \(protocolId)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !clientInfoResult.localIPv4Addresses.isEmpty {
                    Text("Local IPv4: " + clientInfoResult.localIPv4Addresses.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if clientInfoResult.requiresAppRestart {
                    Label("Restart the app before running another ALVR core test.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                ForEach(clientInfoResult.messages, id: \.self) { message in
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let errorDescription = clientInfoResult.errorDescription {
                    Text(errorDescription)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            HStack {
                Button("Start ALVR mDNS Broadcast") {
                    guard let clientInfoResult else { return }
                    Task { await mdnsBroadcaster.start(clientInfo: clientInfoResult) }
                }
                .buttonStyle(.bordered)
                .disabled(clientInfoResult?.success != true || mdnsBroadcaster.isBroadcasting)

                Button("Stop ALVR mDNS Broadcast") {
                    mdnsBroadcaster.stop()
                }
                .buttonStyle(.bordered)
                .disabled(!mdnsBroadcaster.isBroadcasting)
            }

            Text("Broadcast state: \(mdnsBroadcaster.state.description)")
                .font(.caption2)
                .foregroundStyle(mdnsBroadcaster.isBroadcasting ? .green : .secondary)

            if clientInfoResult?.success != true {
                Text("Load ALVR Client Info before starting mDNS broadcast.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !mdnsBroadcaster.serviceName.isEmpty {
                Text("Service name: \(mdnsBroadcaster.serviceName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !mdnsBroadcaster.serviceType.isEmpty {
                Text("Service type: \(mdnsBroadcaster.serviceType)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !mdnsBroadcaster.deviceId.isEmpty {
                Text("Device ID: \(mdnsBroadcaster.deviceId)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !mdnsBroadcaster.protocolId.isEmpty {
                Text("Protocol ID: \(mdnsBroadcaster.protocolId)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !mdnsBroadcaster.portDescription.isEmpty {
                Text("Port: \(mdnsBroadcaster.portDescription)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !mdnsBroadcaster.txtRecordDescription.isEmpty {
                Text("TXT record: \(mdnsBroadcaster.txtRecordDescription)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let lastError = mdnsBroadcaster.lastError {
                Text(lastError)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }

            Text("Before decoder metadata scan: load ALVR client info, start ALVR mDNS broadcast, and confirm the PC ALVR Streamer can discover this headset.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button(isDecoderMetadataScanRunning ? "Running Decoder Metadata Scan..." : "Run Decoder Metadata Scan") {
                isDecoderMetadataScanRunning = true
                decoderMetadataScanResult = nil

                Task {
                    decoderMetadataScanResult = await ALVRClientCoreBridge.shared.runDecoderMetadataScan()
                    isDecoderMetadataScanRunning = false
                }
            }
            .buttonStyle(.bordered)
            .disabled(isDecoderMetadataScanRunning || coreTestsRequireRestart || clientInfoResult?.success != true)

            if let decoderMetadataScanResult {
                Label(
                    decoderMetadataStatusText(for: decoderMetadataScanResult),
                    systemImage: decoderMetadataStatusIcon(for: decoderMetadataScanResult)
                )
                .font(.caption)

                Text("Scan completed: \(decoderMetadataScanResult.scanCompleted ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Received video frames: \(decoderMetadataScanResult.receivedVideoFrames ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(decoderMetadataScanResult.receivedVideoFrames ? .green : .orange)
                Text("Initialized: \(decoderMetadataScanResult.didInitialize ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Set decoder callback: \(decoderMetadataScanResult.didSetDecoderCallback ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Resumed: \(decoderMetadataScanResult.didResume ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Paused: \(decoderMetadataScanResult.didPause ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Destroy skipped: \(decoderMetadataScanResult.destroySkipped ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(decoderMetadataScanResult.destroySkipped ? .orange : .secondary)
                Text("Requires app restart: \(decoderMetadataScanResult.requiresAppRestart ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(decoderMetadataScanResult.requiresAppRestart ? .orange : .secondary)
                Text("Polled events: \(decoderMetadataScanResult.polledEventCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Streaming event seen: \(decoderMetadataScanResult.streamingRelatedEventSeen ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Decoder config event seen: \(decoderMetadataScanResult.decoderConfigEventSeen ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Frame count: \(decoderMetadataScanResult.frameCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Total bytes: \(decoderMetadataScanResult.totalBytes)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let noFramesReceivedMessage = decoderMetadataScanResult.noFramesReceivedMessage {
                    Text(noFramesReceivedMessage)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                if let minBufferSize = decoderMetadataScanResult.minBufferSize {
                    Text("Min buffer size: \(minBufferSize)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let maxBufferSize = decoderMetadataScanResult.maxBufferSize {
                    Text("Max buffer size: \(maxBufferSize)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let lastTimestampNs = decoderMetadataScanResult.lastTimestampNs {
                    Text("Last timestamp ns: \(lastTimestampNs)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let firstFramePrefixHex = decoderMetadataScanResult.firstFramePrefixHex {
                    Text("First prefix: \(firstFramePrefixHex)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let lastFramePrefixHex = decoderMetadataScanResult.lastFramePrefixHex {
                    Text("Last prefix: \(lastFramePrefixHex)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text("Duration: \(decoderMetadataScanResult.durationMilliseconds) ms")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Last step: \(decoderMetadataScanResult.lastStep)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if decoderMetadataScanResult.requiresAppRestart {
                    Label("Restart the app before running another ALVR core test.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if !decoderMetadataScanResult.eventTagNames.isEmpty {
                    Text("Event tags: " + decoderMetadataScanResult.eventTagNames.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !decoderMetadataScanResult.eventTagRawValues.isEmpty {
                    let rawValues = decoderMetadataScanResult.eventTagRawValues.map(String.init).joined(separator: ", ")
                    Text("Event raw values: " + rawValues)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                ForEach(decoderMetadataScanResult.messages, id: \.self) { message in
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let errorDescription = decoderMetadataScanResult.errorDescription {
                    Text(errorDescription)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            Divider()
                .opacity(0.35)

            Button("Run Symbol Smoke Test") {
                symbolSmokeResult = ALVRClientCoreBridge.shared.runSymbolSmokeTest()
            }
            .buttonStyle(.bordered)
            .disabled(coreTestsRequireRestart)

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

            Button("Run Lifecycle Smoke Test") {
                lifecycleSmokeResult = ALVRClientCoreBridge.shared.runLifecycleSmokeTest()
            }
            .buttonStyle(.bordered)
            .disabled(coreTestsRequireRestart)

            if let lifecycleSmokeResult {
                Label(
                    lifecycleSmokeResult.success ? "Lifecycle smoke test passed" : "Lifecycle smoke test failed",
                    systemImage: lifecycleSmokeResult.success ? "checkmark.circle.fill" : "xmark.octagon.fill"
                )
                .font(.caption)

                Text("Initialized: \(lifecycleSmokeResult.didInitialize ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Polled event: \(lifecycleSmokeResult.didPollEvent ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Has event: \(lifecycleSmokeResult.hasEvent ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let eventTagRawValue = lifecycleSmokeResult.eventTagRawValue {
                    Text("Event tag: \(eventTagRawValue)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text("Destroyed: \(lifecycleSmokeResult.didDestroy ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ForEach(lifecycleSmokeResult.messages, id: \.self) { message in
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let errorDescription = lifecycleSmokeResult.errorDescription {
                    Text(errorDescription)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            Button(isControlledResumeSmokeTestRunning ? "Running Controlled Resume/Pause Smoke Test..." : "Run Controlled Resume/Pause Smoke Test") {
                isControlledResumeSmokeTestRunning = true
                controlledResumeSmokeResult = nil

                Task {
                    controlledResumeSmokeResult = await ALVRClientCoreBridge.shared.runControlledResumeSmokeTest()
                    isControlledResumeSmokeTestRunning = false
                }
            }
            .buttonStyle(.bordered)
            .disabled(isControlledResumeSmokeTestRunning || coreTestsRequireRestart)

            if let controlledResumeSmokeResult {
                Label(
                    controlledResumeSmokeResult.success ? "Controlled resume/pause smoke test passed" : "Controlled resume/pause smoke test failed",
                    systemImage: controlledResumeSmokeResult.success ? "checkmark.circle.fill" : "xmark.octagon.fill"
                )
                .font(.caption)

                Text("Initialized: \(controlledResumeSmokeResult.didInitialize ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Resumed: \(controlledResumeSmokeResult.didResume ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Paused: \(controlledResumeSmokeResult.didPause ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Destroyed: \(controlledResumeSmokeResult.didDestroy ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Destroy skipped: \(controlledResumeSmokeResult.destroySkipped ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(controlledResumeSmokeResult.destroySkipped ? .orange : .secondary)
                Text("Requires app restart: \(controlledResumeSmokeResult.requiresAppRestart ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(controlledResumeSmokeResult.requiresAppRestart ? .orange : .secondary)
                Text("Polled events: \(controlledResumeSmokeResult.polledEventCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Duration: \(controlledResumeSmokeResult.durationMilliseconds) ms")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Last step: \(controlledResumeSmokeResult.lastStep)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Dangerous event seen: \(controlledResumeSmokeResult.dangerousEventSeen ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(controlledResumeSmokeResult.dangerousEventSeen ? .orange : .secondary)

                if controlledResumeSmokeResult.requiresAppRestart {
                    Label("Restart the app before running another ALVR core test.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if !controlledResumeSmokeResult.eventTagNames.isEmpty {
                    Text("Event tags: " + controlledResumeSmokeResult.eventTagNames.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !controlledResumeSmokeResult.eventTagRawValues.isEmpty {
                    let rawValues = controlledResumeSmokeResult.eventTagRawValues.map(String.init).joined(separator: ", ")
                    Text("Event raw values: " + rawValues)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !controlledResumeSmokeResult.hudMessages.isEmpty {
                    Text("HUD messages:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    ForEach(controlledResumeSmokeResult.hudMessages, id: \.self) { hudMessage in
                        Text(hudMessage)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(controlledResumeSmokeResult.messages, id: \.self) { message in
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let errorDescription = controlledResumeSmokeResult.errorDescription {
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

    private var coreTestsRequireRestart: Bool {
        controlledResumeSmokeResult?.requiresAppRestart == true
            || decoderMetadataScanResult?.requiresAppRestart == true
    }

    private func decoderMetadataStatusText(for result: ALVRDecoderMetadataScanResult) -> String {
        if result.receivedVideoFrames {
            return "Decoder metadata callback received frames"
        }
        if result.scanCompleted {
            return "Decoder metadata scan completed; no video frames received"
        }
        return "Decoder metadata scan failed"
    }

    private func decoderMetadataStatusIcon(for result: ALVRDecoderMetadataScanResult) -> String {
        if result.receivedVideoFrames {
            return "checkmark.circle.fill"
        }
        if result.scanCompleted {
            return "exclamationmark.triangle.fill"
        }
        return "xmark.octagon.fill"
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
