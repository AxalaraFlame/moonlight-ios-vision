//
//  ALVRDiagnosticsView.swift
//  Moonlight Vision
//
//  Lightweight diagnostics for the placeholder ALVR session.
//

import SwiftUI
import UIKit

struct ALVRDiagnosticsView: View {
    @EnvironmentObject private var viewModel: MainViewModel
    @ObservedObject private var sessionManager = ALVRSessionManager.shared
    @ObservedObject var mdnsBroadcaster: ALVRMdnsBroadcaster
    @ObservedObject var sessionDiagnosticsManager: ALVRSessionDiagnosticsManager
    @State private var symbolSmokeResult: SymbolSmokeResult?
    @State private var lifecycleSmokeResult: LifecycleSmokeResult?
    @State private var controlledResumeSmokeResult: ControlledResumeSmokeResult?
    @State private var clientInfoResult: ALVRClientInfoResult?
    @State private var decoderMetadataScanResult: ALVRDecoderMetadataScanResult?
    @State private var isControlledResumeSmokeTestRunning = false
    @State private var isDecoderMetadataScanRunning = false
    @State private var isStartingHeadsetSession = false
    @State private var headsetSessionStartMode = "manual"
    @State private var mdnsStartedAfterCoreReady = false
    @State private var waitingForPcTrust = false
    @State private var headsetSessionMessage: String?
    @State private var headsetSessionError: String?
    @State private var copyStatusMessage: String?
    @State private var lastCopiedAt: Date?

    private var currentHudSearchText: String {
        ([sessionDiagnosticsManager.lastFullHudMessage].compactMap { $0 } + sessionDiagnosticsManager.recentUniqueHudMessages)
            .joined(separator: "\n")
            .lowercased()
    }

    private var streamingStartedCount: Int {
        countEvent("STREAMING_STARTED", in: sessionDiagnosticsManager.eventTagNames)
    }

    private var streamingStoppedCount: Int {
        countEvent("STREAMING_STOPPED", in: sessionDiagnosticsManager.eventTagNames)
    }

    private var successfulConnectionSeen: Bool {
        streamingStartedCount > 0 || containsAny(currentHudSearchText, ["successful connection", "stream will begin soon"])
    }

    private var effectiveWaitingForPcTrust: Bool {
        waitingForPcTrust && !successfulConnectionSeen
    }

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

            Button("Tap Test") {
                print("[ALVR UI] Tap Test clicked")
            }
            .buttonStyle(.bordered)

            Button("Copy ALVR Diagnostics Summary") {
                copyDiagnosticsSummary()
            }
            .buttonStyle(.bordered)

            if let copyStatusMessage {
                Text(copyStatusMessage)
                    .font(.caption2)
                    .foregroundStyle(.green)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Manual: Load ALVR Client Info") {
                print("[ALVR UI] Load ALVR Client Info tapped")
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

                diagnosticMessages(clientInfoResult.messages)

                if let errorDescription = clientInfoResult.errorDescription {
                    Text(errorDescription)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            HStack {
                Button("Manual: Start ALVR mDNS Broadcast") {
                    guard let clientInfoResult else { return }
                    Task { await mdnsBroadcaster.start(clientInfo: clientInfoResult) }
                }
                .buttonStyle(.bordered)
                .disabled(clientInfoResult?.success != true || mdnsBroadcaster.isBroadcasting)

                Button("Manual: Stop ALVR mDNS Broadcast") {
                    mdnsBroadcaster.stop()
                }
                .buttonStyle(.bordered)
                .disabled(!mdnsBroadcaster.isBroadcasting)
            }

            Text("Broadcast state: \(mdnsBroadcaster.state.description)")
                .font(.caption2)
                .foregroundStyle(mdnsBroadcaster.isBroadcasting ? .green : .secondary)
            Text("Listener state: \(mdnsBroadcaster.listenerStateDescription)")
                .font(.caption2)
                .foregroundStyle(mdnsBroadcaster.listenerReady ? .green : .secondary)
            Text("Listener ready: \(mdnsBroadcaster.listenerReady ? "true" : "false")")
                .font(.caption2)
                .foregroundStyle(mdnsBroadcaster.listenerReady ? .green : .secondary)
            Text("Listener restart count: \(mdnsBroadcaster.listenerRestartCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if !mdnsBroadcaster.listenerStartTimeDescription.isEmpty {
                Text("Listener started: \(mdnsBroadcaster.listenerStartTimeDescription)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !mdnsBroadcaster.activeHostname.isEmpty {
                Text("Hostname: \(mdnsBroadcaster.activeHostname)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if let deviceId = clientInfoResult?.deviceId {
                Text("Hostname: \(deviceId)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

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
                Text("mDNS service: \(mdnsBroadcaster.serviceType)")
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
                Text("Active port: \(mdnsBroadcaster.portDescription)")
                    .font(.caption2)
                    .foregroundStyle(mdnsBroadcaster.activePort == nil ? Color.secondary : Color.green)
            }

            if let recommendedManualConnectionAddress = mdnsBroadcaster.recommendedManualConnectionAddress {
                Text("Recommended PC manual address: \(recommendedManualConnectionAddress)")
                    .font(.caption2)
                    .foregroundStyle(.green)
                    .textSelection(.enabled)
            } else if mdnsBroadcaster.listenerReady {
                Text("Warning: no usable LAN IPv4 found for manual PC connection.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !mdnsBroadcaster.localIPv4Candidates.isEmpty {
                Text("Local IPv4 candidates: " + mdnsBroadcaster.localIPv4Candidates.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if clientInfoResult?.success == true {
                Text("Warning: no usable LAN IPv4 found. Check Wi-Fi/LAN connectivity.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !mdnsBroadcaster.ignoredIPv4Candidates.isEmpty {
                Text("Ignored IPv4 candidates: " + mdnsBroadcaster.ignoredIPv4Candidates.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let listenerPortChangedWarning = mdnsBroadcaster.listenerPortChangedWarning {
                Text(listenerPortChangedWarning)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
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
                Text("NAL scan enabled: \(decoderMetadataScanResult.nalScanEnabled ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Codec guess: \(decoderMetadataScanResult.codecGuess)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("NAL unit count: \(decoderMetadataScanResult.nalUnitCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Received HEVC slices: \(decoderMetadataScanResult.hevcSliceCount > 0 ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(decoderMetadataScanResult.hevcSliceCount > 0 ? .green : .secondary)
                Text("HEVC TRAIL/slice/non-IDR: \(decoderMetadataScanResult.hevcTrailCount)/\(decoderMetadataScanResult.hevcSliceCount)/\(decoderMetadataScanResult.hevcNonIdrCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("HEVC VPS/SPS/PPS/IDR/CRA: \(decoderMetadataScanResult.hevcVpsCount)/\(decoderMetadataScanResult.hevcSpsCount)/\(decoderMetadataScanResult.hevcPpsCount)/\(decoderMetadataScanResult.hevcIdrCount)/\(decoderMetadataScanResult.hevcCraCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("H264 SPS/PPS/IDR/non-IDR: \(decoderMetadataScanResult.h264SpsCount)/\(decoderMetadataScanResult.h264PpsCount)/\(decoderMetadataScanResult.h264IdrCount)/\(decoderMetadataScanResult.h264NonIdrCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("SEI count: \(decoderMetadataScanResult.seiCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Parameter sets ready: \(decoderMetadataScanResult.parameterSetsReady ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(decoderMetadataScanResult.parameterSetsReady ? .green : .orange)
                Text("VideoToolbox ready: \(decoderMetadataScanResult.videoToolboxReady ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(decoderMetadataScanResult.videoToolboxReady ? .green : .orange)
                Text("Has parameter sets: \(decoderMetadataScanResult.hasParameterSets ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(decoderMetadataScanResult.hasParameterSets ? .green : .secondary)
                Text("Has IDR: \(decoderMetadataScanResult.hasIdr ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(decoderMetadataScanResult.hasIdr ? .green : .secondary)

                if !decoderMetadataScanResult.firstNalTypes.isEmpty {
                    Text("First NAL types: " + decoderMetadataScanResult.firstNalTypes.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !decoderMetadataScanResult.missingDecoderPrerequisites.isEmpty {
                    Text("Missing decoder prerequisites: " + decoderMetadataScanResult.missingDecoderPrerequisites.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

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

                diagnosticMessages(decoderMetadataScanResult.messages)

                if let errorDescription = decoderMetadataScanResult.errorDescription {
                    Text(errorDescription)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            Text("Recommended order: start the ALVR headset session first so the core, decoder callback, and event loop are ready; then advertise mDNS and let the PC ALVR Streamer discover, trust, and connect to this headset.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack {
                Button(isStartingHeadsetSession ? "Starting ALVR Headset Session..." : "Start ALVR Headset Session") {
                    Task { await startHeadsetSession() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    isStartingHeadsetSession
                        || coreTestsRequireRestart
                        || sessionDiagnosticsManager.isRunning
                        || sessionDiagnosticsManager.isStopping
                )

                Button("Stop ALVR Headset Session") {
                    stopHeadsetSession()
                }
                .buttonStyle(.bordered)
                .disabled(!sessionDiagnosticsManager.isRunning && !mdnsBroadcaster.isBroadcasting)
            }

            if let headsetSessionMessage {
                Text(headsetSessionMessage)
                    .font(.caption2)
                    .foregroundStyle(.green)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let headsetSessionError {
                Text(headsetSessionError)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            headsetSessionStatusPanel

            Text("Headset session start mode: \(headsetSessionStartMode)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("ALVR core ready: \(sessionDiagnosticsManager.alvrCoreReady ? "true" : "false")")
                .font(.caption2)
                .foregroundStyle(sessionDiagnosticsManager.alvrCoreReady ? .green : .secondary)
            Text("Event loop running: \(sessionDiagnosticsManager.eventLoopRunning ? "true" : "false")")
                .font(.caption2)
                .foregroundStyle(sessionDiagnosticsManager.eventLoopRunning ? .green : .secondary)
            Text("mDNS started after core ready: \(mdnsStartedAfterCoreReady ? "true" : "false")")
                .font(.caption2)
                .foregroundStyle(mdnsStartedAfterCoreReady ? .green : .secondary)
            Text("Waiting for PC trust/connect: \(effectiveWaitingForPcTrust ? "true" : "false")")
                .font(.caption2)
                .foregroundStyle(effectiveWaitingForPcTrust ? .orange : .secondary)

            HStack {
                Button("Manual: Start ALVR Session Diagnostics") {
                    headsetSessionStartMode = "manual"
                    mdnsStartedAfterCoreReady = false
                    waitingForPcTrust = false
                    headsetSessionMessage = "Manual session diagnostics started. Start mDNS afterward when the event loop is running."
                    headsetSessionError = nil
                    sessionDiagnosticsManager.start(clientInfo: clientInfoResult)
                }
                .buttonStyle(.bordered)
                .disabled(
                    coreTestsRequireRestart
                        || sessionDiagnosticsManager.isRunning
                        || sessionDiagnosticsManager.isStopping
                        || clientInfoResult?.success != true
                )

                Button("Manual: Stop ALVR Session Diagnostics") {
                    sessionDiagnosticsManager.stop()
                }
                .buttonStyle(.bordered)
                .disabled(!sessionDiagnosticsManager.isRunning)
            }

            Text("Session diagnostics state: \(sessionDiagnosticsManager.state.description)")
                .font(.caption2)
                .foregroundStyle(sessionDiagnosticsManager.isRunning ? .green : .secondary)
            if let lifecycleWarningMessage = sessionDiagnosticsManager.lifecycleWarningMessage {
                Text(lifecycleWarningMessage)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Elapsed: \(sessionDiagnosticsManager.elapsedSeconds) s")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Streaming event seen: \(sessionDiagnosticsManager.streamingEventSeen ? "true" : "false")")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Decoder config event seen: \(sessionDiagnosticsManager.decoderConfigEventSeen ? "true" : "false")")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Haptics event seen: \(sessionDiagnosticsManager.hapticsEventSeen ? "true" : "false")")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Frame count: \(sessionDiagnosticsManager.frameCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Total bytes: \(sessionDiagnosticsManager.totalBytes)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("NAL scan enabled: \(sessionDiagnosticsManager.nalScanEnabled ? "true" : "false")")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Codec guess: \(sessionDiagnosticsManager.codecGuess)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("NAL unit count: \(sessionDiagnosticsManager.nalUnitCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Received HEVC slices: \(sessionDiagnosticsManager.hevcSliceCount > 0 ? "true" : "false")")
                .font(.caption2)
                .foregroundStyle(sessionDiagnosticsManager.hevcSliceCount > 0 ? .green : .secondary)
            Text("HEVC TRAIL/slice/non-IDR: \(sessionDiagnosticsManager.hevcTrailCount)/\(sessionDiagnosticsManager.hevcSliceCount)/\(sessionDiagnosticsManager.hevcNonIdrCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("HEVC VPS/SPS/PPS/IDR/CRA: \(sessionDiagnosticsManager.hevcVpsCount)/\(sessionDiagnosticsManager.hevcSpsCount)/\(sessionDiagnosticsManager.hevcPpsCount)/\(sessionDiagnosticsManager.hevcIdrCount)/\(sessionDiagnosticsManager.hevcCraCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("H264 SPS/PPS/IDR/non-IDR: \(sessionDiagnosticsManager.h264SpsCount)/\(sessionDiagnosticsManager.h264PpsCount)/\(sessionDiagnosticsManager.h264IdrCount)/\(sessionDiagnosticsManager.h264NonIdrCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("SEI count: \(sessionDiagnosticsManager.seiCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Parameter sets ready: \(sessionDiagnosticsManager.parameterSetsReady ? "true" : "false")")
                .font(.caption2)
                .foregroundStyle(sessionDiagnosticsManager.parameterSetsReady ? .green : .orange)
            Text("VideoToolbox ready: \(sessionDiagnosticsManager.videoToolboxReady ? "true" : "false")")
                .font(.caption2)
                .foregroundStyle(sessionDiagnosticsManager.videoToolboxReady ? .green : .orange)
            Text("Has parameter sets: \(sessionDiagnosticsManager.hasParameterSets ? "true" : "false")")
                .font(.caption2)
                .foregroundStyle(sessionDiagnosticsManager.hasParameterSets ? .green : .secondary)
            Text("Has IDR: \(sessionDiagnosticsManager.hasIdr ? "true" : "false")")
                .font(.caption2)
                .foregroundStyle(sessionDiagnosticsManager.hasIdr ? .green : .secondary)
            Text("Last step: \(sessionDiagnosticsManager.lastStep)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Decoder automation state: \(sessionDiagnosticsManager.decoderAutomationState.description)")
                .font(.caption2)
                .foregroundStyle(sessionDiagnosticsManager.decoderReady ? .green : .secondary)
            Text("Decoder config source: \(sessionDiagnosticsManager.decoderConfigSource)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Decoder generation: \(sessionDiagnosticsManager.decoderGeneration)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Decoder ready: \(sessionDiagnosticsManager.decoderReady ? "true" : "false")")
                .font(.caption2)
                .foregroundStyle(sessionDiagnosticsManager.decoderReady ? .green : .secondary)
            Text("Decoder created automatically: \(sessionDiagnosticsManager.decoderCreatedAutomatically ? "true" : "false")")
                .font(.caption2)
                .foregroundStyle(sessionDiagnosticsManager.decoderCreatedAutomatically ? .green : .secondary)
            Text("Last rebuild reason: \(sessionDiagnosticsManager.lastRebuildReason)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Last config source: \(sessionDiagnosticsManager.lastConfigSource)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Auto decoder creation status: \(sessionDiagnosticsManager.autoDecoderCreationStatus)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Last decoder automation message: \(sessionDiagnosticsManager.lastDecoderAutomationMessage)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)

            VStack(alignment: .leading, spacing: 6) {
                Button("Request Keyframe / Parameter Sets") {
                    sessionDiagnosticsManager.requestKeyframeParameterSets()
                }
                .buttonStyle(.bordered)
                .disabled(!sessionDiagnosticsManager.keyframeRequestAvailable)

                Text("Returning false once may restart or disturb the PC stream. Use this only for diagnostics.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Keyframe request available: \(sessionDiagnosticsManager.keyframeRequestAvailable ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(sessionDiagnosticsManager.keyframeRequestAvailable ? .green : .secondary)
                Text("Keyframe request pending: \(sessionDiagnosticsManager.keyframeRequestPending ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(sessionDiagnosticsManager.keyframeRequestPending ? .orange : .secondary)
                Text("Keyframe request triggered: \(sessionDiagnosticsManager.keyframeRequestTriggered ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(sessionDiagnosticsManager.keyframeRequestTriggered ? .green : .secondary)
                Text("Keyframe request count: \(sessionDiagnosticsManager.keyframeRequestCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Frames since keyframe request: \(sessionDiagnosticsManager.framesSinceKeyframeRequest)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let secondsSinceKeyframeRequest = sessionDiagnosticsManager.secondsSinceKeyframeRequest {
                    Text("Seconds since keyframe request: \(String(format: "%.1f", secondsSinceKeyframeRequest))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let keyframeRequestMessage = sessionDiagnosticsManager.keyframeRequestMessage {
                    Text(keyframeRequestMessage)
                        .font(.caption2)
                        .foregroundStyle(sessionDiagnosticsManager.keyframeRequestTriggered ? .green : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if clientInfoResult?.success != true {
                Text("Load ALVR Client Info before starting session diagnostics.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !mdnsBroadcaster.isBroadcasting {
                Text("mDNS broadcast is not running. This is OK for the core-first flow; start mDNS after the ALVR event loop is running.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let lastTimestampNs = sessionDiagnosticsManager.lastTimestampNs {
                Text("Last timestamp ns: \(lastTimestampNs)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let minBufferSize = sessionDiagnosticsManager.minBufferSize {
                Text("Min buffer size: \(minBufferSize)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let maxBufferSize = sessionDiagnosticsManager.maxBufferSize {
                Text("Max buffer size: \(maxBufferSize)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let firstFramePrefixHex = sessionDiagnosticsManager.firstFramePrefixHex {
                Text("First prefix: \(firstFramePrefixHex)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let lastFramePrefixHex = sessionDiagnosticsManager.lastFramePrefixHex {
                Text("Last prefix: \(lastFramePrefixHex)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !sessionDiagnosticsManager.eventTagNames.isEmpty {
                Text("Event tags: " + sessionDiagnosticsManager.eventTagNames.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !sessionDiagnosticsManager.eventTagRawValues.isEmpty {
                let rawValues = sessionDiagnosticsManager.eventTagRawValues.map(String.init).joined(separator: ", ")
                Text("Event raw values: " + rawValues)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !sessionDiagnosticsManager.firstNalTypes.isEmpty {
                Text("First NAL types: " + sessionDiagnosticsManager.firstNalTypes.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !sessionDiagnosticsManager.missingDecoderPrerequisites.isEmpty {
                Text("Missing decoder prerequisites: " + sessionDiagnosticsManager.missingDecoderPrerequisites.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            if let lastFullHudMessage = sessionDiagnosticsManager.lastFullHudMessage {
                Text("Last full HUD message:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("Last full HUD message length: \(sessionDiagnosticsManager.lastFullHudMessageLength)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Truncated: \(sessionDiagnosticsManager.lastFullHudMessageIsTruncated ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(sessionDiagnosticsManager.lastFullHudMessageIsTruncated ? .orange : .secondary)

                Text("Raw HUD message debug preview: \(debugPreview(for: lastFullHudMessage))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
                    .textSelection(.enabled)

                hudMessageText(lastFullHudMessage)
            }

            if !sessionDiagnosticsManager.recentUniqueHudMessages.isEmpty {
                Text("Recent unique HUD messages:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Recent unique HUD messages count: \(sessionDiagnosticsManager.recentUniqueHudMessages.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                hudMessages(sessionDiagnosticsManager.recentUniqueHudMessages)
            }

            if sessionDiagnosticsManager.hasOnlyHudMessagesWithoutStreamingPath {
                Label(
                    "PC has not entered ALVR streaming path yet. Check ALVR Streamer trust/connect state, SteamVR driver, firewall, codec settings.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }

            Text("Normally this diagnostics session automatically reads decoder config or captures in-band parameter sets, then creates the HEVC decoder skeleton. Manual buttons below are only for debugging.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("Manual Decoder Config Snapshot") {
                sessionDiagnosticsManager.readDecoderConfigSnapshot(
                    triggerReason: sessionDiagnosticsSnapshotTriggerReason
                )
            }
            .buttonStyle(.bordered)
            .disabled(!sessionDiagnosticsManager.canReadDecoderConfigSnapshot)

            if let disabledReason = sessionDiagnosticsManager.decoderConfigSnapshotDisabledReason {
                Text(disabledReason)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            Text("Frame data may arrive before this diagnostics tool sees DECODER_CONFIG. In that case, automatic in-band NAL capture waits for VPS/SPS/PPS instead of calling alvr_get_decoder_config.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let decoderConfigSnapshot = sessionDiagnosticsManager.decoderConfigSnapshot {
                Label(
                    decoderConfigSnapshot.success ? "Decoder config snapshot read" : "Decoder config snapshot unavailable",
                    systemImage: decoderConfigSnapshot.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                )
                .font(.caption)

                Text("Decoder config attempted: \(decoderConfigSnapshot.attempted ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Decoder config success: \(decoderConfigSnapshot.success ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(decoderConfigSnapshot.success ? .green : .orange)
                Text("Decoder config size: \(decoderConfigSnapshot.size)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Trigger reason: \(decoderConfigSnapshot.triggerReason)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Decoder config NAL count: \(decoderConfigSnapshot.configNalUnitCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Decoder config codec guess: \(decoderConfigSnapshot.configCodecGuess)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Config HEVC VPS/SPS/PPS: \(decoderConfigSnapshot.hevcVpsCount)/\(decoderConfigSnapshot.hevcSpsCount)/\(decoderConfigSnapshot.hevcPpsCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Config H264 SPS/PPS: \(decoderConfigSnapshot.h264SpsCount)/\(decoderConfigSnapshot.h264PpsCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Config parameter sets ready: \(decoderConfigSnapshot.parameterSetsReady ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(decoderConfigSnapshot.parameterSetsReady ? .green : .orange)
                Text("Config VideoToolbox ready: \(decoderConfigSnapshot.videoToolboxReady ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(decoderConfigSnapshot.videoToolboxReady ? .green : .orange)

                if let hevcVpsSize = decoderConfigSnapshot.hevcVpsSize {
                    Text("HEVC VPS size: \(hevcVpsSize)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let hevcSpsSize = decoderConfigSnapshot.hevcSpsSize {
                    Text("HEVC SPS size: \(hevcSpsSize)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let hevcPpsSize = decoderConfigSnapshot.hevcPpsSize {
                    Text("HEVC PPS size: \(hevcPpsSize)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let h264SpsSize = decoderConfigSnapshot.h264SpsSize {
                    Text("H264 SPS size: \(h264SpsSize)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let h264PpsSize = decoderConfigSnapshot.h264PpsSize {
                    Text("H264 PPS size: \(h264PpsSize)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !decoderConfigSnapshot.configNalTypes.isEmpty {
                    Text("First config NAL types: " + decoderConfigSnapshot.configNalTypes.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !decoderConfigSnapshot.missingDecoderPrerequisites.isEmpty {
                    Text("Config missing prerequisites: " + decoderConfigSnapshot.missingDecoderPrerequisites.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                if let prefixHex = decoderConfigSnapshot.prefixHex {
                    Text("Decoder config prefix hex: \(prefixHex)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let parameterSetPrefixHex = decoderConfigSnapshot.parameterSetPrefixHex {
                    Text("Parameter set prefix hex: \(parameterSetPrefixHex)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let asciiPreview = decoderConfigSnapshot.asciiPreview {
                    Text("Decoder config ASCII preview: \(asciiPreview)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                diagnosticMessages(decoderConfigSnapshot.messages)

                if let errorDescription = decoderConfigSnapshot.errorDescription {
                    Text(errorDescription)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            Text("This only creates the VideoToolbox decoder session. It does not feed frames or render SteamVR.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("Manual HEVC Decoder Skeleton") {
                sessionDiagnosticsManager.createHEVCDecoderSkeletonFromCurrentConfig()
            }
            .buttonStyle(.bordered)
            .disabled(!sessionDiagnosticsManager.canCreateHEVCDecoderSkeleton)

            if let videoToolboxDecoderCreationResult = sessionDiagnosticsManager.videoToolboxDecoderCreationResult {
                Label(
                    videoToolboxDecoderCreationResult.success ? "HEVC decoder skeleton created" : "HEVC decoder skeleton failed",
                    systemImage: videoToolboxDecoderCreationResult.success ? "checkmark.circle.fill" : "xmark.octagon.fill"
                )
                .font(.caption)

                Text("Codec: \(videoToolboxDecoderCreationResult.codec)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Created format description: \(videoToolboxDecoderCreationResult.createdFormatDescription ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(videoToolboxDecoderCreationResult.createdFormatDescription ? .green : .orange)
                Text("Created decompression session: \(videoToolboxDecoderCreationResult.createdDecompressionSession ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(videoToolboxDecoderCreationResult.createdDecompressionSession ? .green : .orange)
                Text("Format description status: \(videoToolboxDecoderCreationResult.formatDescriptionStatus)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Decompression session status: \(videoToolboxDecoderCreationResult.decompressionSessionStatus)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("HEVC VPS/SPS/PPS sizes: \(videoToolboxDecoderCreationResult.vpsSize)/\(videoToolboxDecoderCreationResult.spsSize)/\(videoToolboxDecoderCreationResult.ppsSize)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("NAL unit header length: \(videoToolboxDecoderCreationResult.nalUnitHeaderLength)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                diagnosticMessages(videoToolboxDecoderCreationResult.messages)

                if let errorDescription = videoToolboxDecoderCreationResult.errorDescription {
                    Text(errorDescription)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            Button("Feed Test Frames to HEVC Decoder") {
                sessionDiagnosticsManager.feedTestFramesToHEVCDecoder()
            }
            .buttonStyle(.bordered)
            .disabled(!sessionDiagnosticsManager.canFeedTestFramesToHEVCDecoder)

            Button("Request IDR for Decode Test") {
                sessionDiagnosticsManager.requestDecodeTestIdr()
            }
            .buttonStyle(.bordered)
            .disabled(!sessionDiagnosticsManager.decodeTestIdrRequestAvailable)

            if !sessionDiagnosticsManager.decodeTestIdrRequestAvailable,
               let disabledReason = sessionDiagnosticsManager.decodeTestIdrRequestDisabledReason {
                Text("Request IDR disabled: \(disabledReason)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("This returns false once from the decoder callback to ask the streamer for a new keyframe. Use only for diagnostics.")
                .font(.caption2)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)

            if let videoToolboxFrameFeedSummary = sessionDiagnosticsManager.videoToolboxFrameFeedSummary {
                Label(
                    videoToolboxFrameFeedSummary.decodedFrameCount > 0 ? "HEVC frame decode smoke test received CVPixelBuffer" : "HEVC frame decode smoke test waiting for frames",
                    systemImage: videoToolboxFrameFeedSummary.decodedFrameCount > 0 ? "checkmark.circle.fill" : "clock"
                )
                .font(.caption)

                Text("Frame feed enabled: \(videoToolboxFrameFeedSummary.feedEnabled ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Frame feed test enabled: \(sessionDiagnosticsManager.frameFeedTestEnabled ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(sessionDiagnosticsManager.frameFeedTestEnabled ? .green : .secondary)
                Text("Frame feed waiting for IDR/CRA: \(sessionDiagnosticsManager.frameFeedWaitingForIdr ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(sessionDiagnosticsManager.frameFeedWaitingForIdr ? .orange : .secondary)
                Text("Frame feed can copy frames: \(sessionDiagnosticsManager.frameFeedCanCopyFrames ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(sessionDiagnosticsManager.frameFeedCanCopyFrames ? .green : .secondary)
                if let frameFeedDisabledReason = sessionDiagnosticsManager.frameFeedDisabledReason {
                    Text("Frame feed disabled reason: \(frameFeedDisabledReason)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let frameFeedLastSkipReason = sessionDiagnosticsManager.frameFeedLastSkipReason {
                    Text("Frame feed last skip reason: \(frameFeedLastSkipReason)")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Frame feed copied after IDR request: \(sessionDiagnosticsManager.frameFeedCopiedAfterIdrRequest ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(sessionDiagnosticsManager.frameFeedCopiedAfterIdrRequest ? .green : .secondary)
                if let frameFeedStartedAtFrameCount = sessionDiagnosticsManager.frameFeedStartedAtFrameCount {
                    Text("Frame feed started at frame count: \(frameFeedStartedAtFrameCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text("Feed callback seen frames: \(sessionDiagnosticsManager.feedCallbackSeenFrameCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Feed callback saw IDR/CRA: \(sessionDiagnosticsManager.feedCallbackSawIdrOrCraCount)")
                    .font(.caption2)
                    .foregroundStyle(sessionDiagnosticsManager.feedCallbackSawIdrOrCraCount > 0 ? .green : .secondary)
                if !sessionDiagnosticsManager.feedCallbackLastNalTypes.isEmpty {
                    Text("Feed callback last NAL types: \(sessionDiagnosticsManager.feedCallbackLastNalTypes.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                if let feedCallbackLastDecision = sessionDiagnosticsManager.feedCallbackLastDecision {
                    Text("Feed callback last decision: \(feedCallbackLastDecision)")
                        .font(.caption2)
                        .foregroundStyle(feedCallbackLastDecision == "copied" ? .green : .orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let feedCallbackLastSkipReason = sessionDiagnosticsManager.feedCallbackLastSkipReason {
                    Text("Feed callback last skip reason: \(feedCallbackLastSkipReason)")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Pending decode frames: \(sessionDiagnosticsManager.pendingDecodeFrameCount)")
                    .font(.caption2)
                    .foregroundStyle(sessionDiagnosticsManager.pendingDecodeFrameCount > 0 ? .orange : .secondary)
                if videoToolboxFrameFeedSummary.feedEnabled,
                   videoToolboxFrameFeedSummary.copiedFrameCount == 0,
                   sessionDiagnosticsManager.decoderReady {
                    Text("Decoder is ready, but feed test is waiting for a new IDR/CRA frame. Click Request IDR for Decode Test.")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Copied frames: \(videoToolboxFrameFeedSummary.copiedFrameCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Copied IDR / CRA frames: \(videoToolboxFrameFeedSummary.copiedIdrFrameCount) / \(videoToolboxFrameFeedSummary.copiedCraFrameCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Submitted frames: \(videoToolboxFrameFeedSummary.submittedFrameCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Submitted IDR / CRA frames: \(videoToolboxFrameFeedSummary.submittedIdrFrameCount) / \(videoToolboxFrameFeedSummary.submittedCraFrameCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Decoded frames: \(videoToolboxFrameFeedSummary.decodedFrameCount)")
                    .font(.caption2)
                    .foregroundStyle(videoToolboxFrameFeedSummary.decodedFrameCount > 0 ? .green : .secondary)
                Text("Fed frame was random access: \(videoToolboxFrameFeedSummary.fedFrameWasRandomAccess ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(videoToolboxFrameFeedSummary.fedFrameWasRandomAccess ? .green : .orange)
                if !videoToolboxFrameFeedSummary.fedFrameNalTypes.isEmpty {
                    Text("Fed frame NAL types: \(videoToolboxFrameFeedSummary.fedFrameNalTypes.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                if let copiedFramePrefixHex = videoToolboxFrameFeedSummary.copiedFramePrefixHex {
                    Text("Copied frame prefix hex: \(copiedFramePrefixHex)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                if let convertedLengthPrefixedPrefixHex = videoToolboxFrameFeedSummary.convertedLengthPrefixedPrefixHex {
                    Text("Length-prefixed prefix hex: \(convertedLengthPrefixedPrefixHex)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                Text("Used synthetic PTS: \(videoToolboxFrameFeedSummary.usedSyntheticPts ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let samplePtsDescription = videoToolboxFrameFeedSummary.samplePtsDescription {
                    Text("Sample PTS: \(samplePtsDescription)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text("Annex-B / converted NAL count: \(videoToolboxFrameFeedSummary.annexBNalCount) / \(videoToolboxFrameFeedSummary.convertedNalCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Converted sample size: \(videoToolboxFrameFeedSummary.convertedSampleSize)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let firstConvertedNalLength = videoToolboxFrameFeedSummary.firstConvertedNalLength {
                    Text("First converted NAL length: \(firstConvertedNalLength)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let conversionError = videoToolboxFrameFeedSummary.conversionError {
                    Text("Conversion error: \(conversionError)")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                Text("Waited for async decode frames: \(videoToolboxFrameFeedSummary.didWaitForAsynchronousFrames ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Did call alvr_report_frame_decoded: \(videoToolboxFrameFeedSummary.didCallAlvrReportFrameDecoded ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(videoToolboxFrameFeedSummary.didCallAlvrReportFrameDecoded ? .orange : .secondary)

                if let lastDecodeCallStatus = videoToolboxFrameFeedSummary.lastDecodeCallStatus {
                    Text("Last decode call status: \(lastDecodeCallStatus)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let lastCallbackStatus = videoToolboxFrameFeedSummary.lastCallbackStatus {
                    Text("Last callback status: \(lastCallbackStatus)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let lastInfoFlagsRawValue = videoToolboxFrameFeedSummary.lastInfoFlagsRawValue {
                    Text("Last info flags: \(lastInfoFlagsRawValue)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let width = videoToolboxFrameFeedSummary.lastPixelBufferWidth,
                   let height = videoToolboxFrameFeedSummary.lastPixelBufferHeight {
                    Text("Last pixel buffer: \(width)x\(height)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let lastPixelFormat = videoToolboxFrameFeedSummary.lastPixelFormat {
                    Text("Last pixel format: \(lastPixelFormat)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let lastPlaneCount = videoToolboxFrameFeedSummary.lastPlaneCount {
                    Text("Last plane count: \(lastPlaneCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !videoToolboxFrameFeedSummary.lastBytesPerRowByPlane.isEmpty {
                    let bytesPerRow = videoToolboxFrameFeedSummary.lastBytesPerRowByPlane.map(String.init).joined(separator: ", ")
                    Text("Last bytes per row by plane: \(bytesPerRow)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let lastHasIOSurface = videoToolboxFrameFeedSummary.lastHasIOSurface {
                    Text("Last pixel buffer has IOSurface: \(lastHasIOSurface ? "true" : "false")")
                        .font(.caption2)
                        .foregroundStyle(lastHasIOSurface ? .green : .secondary)
                }

                if let lastIsMetalCompatible = videoToolboxFrameFeedSummary.lastIsMetalCompatible {
                    Text("Last pixel buffer Metal compatible: \(lastIsMetalCompatible ? "true" : "false")")
                        .font(.caption2)
                        .foregroundStyle(lastIsMetalCompatible ? .green : .orange)
                }

                if let lastMetalCompatibilityHint = videoToolboxFrameFeedSummary.lastMetalCompatibilityHint {
                    Text("Metal compatibility hint: \(lastMetalCompatibilityHint)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text("Latest decoded frame snapshot retained: \(videoToolboxFrameFeedSummary.hasLatestDecodedPixelBufferSnapshot ? "true" : "false")")
                    .font(.caption2)
                    .foregroundStyle(videoToolboxFrameFeedSummary.hasLatestDecodedPixelBufferSnapshot ? .green : .secondary)

                if let lastDecodedTimestampNs = videoToolboxFrameFeedSummary.lastDecodedTimestampNs {
                    Text("Last decoded timestamp ns: \(lastDecodedTimestampNs)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !videoToolboxFrameFeedSummary.decodeErrors.isEmpty {
                    Text("Decode errors: " + videoToolboxFrameFeedSummary.decodeErrors.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                diagnosticMessages(videoToolboxFrameFeedSummary.messages)
            }

            Text("Decode-test IDR request available: \(sessionDiagnosticsManager.decodeTestIdrRequestAvailable ? "true" : "false")")
                .font(.caption2)
                .foregroundStyle(sessionDiagnosticsManager.decodeTestIdrRequestAvailable ? .green : .secondary)
            Text("Decode-test IDR request pending: \(sessionDiagnosticsManager.decodeTestIdrRequestPending ? "true" : "false")")
                .font(.caption2)
                .foregroundStyle(sessionDiagnosticsManager.decodeTestIdrRequestPending ? .orange : .secondary)
            Text("Decode-test IDR request triggered: \(sessionDiagnosticsManager.decodeTestIdrRequestTriggered ? "true" : "false")")
                .font(.caption2)
                .foregroundStyle(sessionDiagnosticsManager.decodeTestIdrRequestTriggered ? .green : .secondary)
            Text("Decode-test IDR request count: \(sessionDiagnosticsManager.decodeTestIdrRequestCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Frames since decode-test IDR request: \(sessionDiagnosticsManager.framesSinceDecodeTestIdrRequest)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let secondsSinceDecodeTestIdrRequest = sessionDiagnosticsManager.secondsSinceDecodeTestIdrRequest {
                Text("Seconds since decode-test IDR request: \(String(format: "%.1f", secondsSinceDecodeTestIdrRequest))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let decodeTestIdrRequestMessage = sessionDiagnosticsManager.decodeTestIdrRequestMessage {
                Text(decodeTestIdrRequestMessage)
                    .font(.caption2)
                    .foregroundStyle(sessionDiagnosticsManager.decodeTestIdrRequestTriggered ? .green : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if sessionDiagnosticsManager.requiresAppRestart {
                Label("Restart the app before running another ALVR core test.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            diagnosticMessages(sessionDiagnosticsManager.messages)

            if let errorMessage = sessionDiagnosticsManager.errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
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

                diagnosticMessages(symbolSmokeResult.messages)

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

                diagnosticMessages(lifecycleSmokeResult.messages)

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

                    hudMessages(controlledResumeSmokeResult.hudMessages)
                }

                diagnosticMessages(controlledResumeSmokeResult.messages)

                if let errorDescription = controlledResumeSmokeResult.errorDescription {
                    Text(errorDescription)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(14)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .textSelection(.enabled)
        // TODO: Migrate ALVR transport, pose input, and controller input diagnostics from alvr-org/alvr-visionos.
        .onAppear {
            print("[ALVRDiagnosticsView] appear")
        }
        .onDisappear {
            print("[ALVRDiagnosticsView] disappear")
            if sessionDiagnosticsManager.isRunning {
                print("[ALVRDiagnosticsView] warning: disappeared while ALVR session diagnostics is running; leaving session active.")
            }
        }
    }

    private var coreTestsRequireRestart: Bool {
        controlledResumeSmokeResult?.requiresAppRestart == true
            || decoderMetadataScanResult?.requiresAppRestart == true
            || sessionDiagnosticsManager.requiresAppRestart
    }

    private var sessionDiagnosticsSnapshotTriggerReason: String {
        if sessionDiagnosticsManager.decoderConfigEventSeen {
            return "decoderConfigEventSeen"
        }
        return "Manual snapshot"
    }

    private var headsetSessionStatusPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Headset session status", systemImage: "visionpro")
                .font(.caption)
                .foregroundStyle(.primary)

            statusLine("headsetSessionStartMode", headsetSessionStartMode)
            statusLine("alvrCoreReady", sessionDiagnosticsManager.alvrCoreReady ? "true" : "false", isPositive: sessionDiagnosticsManager.alvrCoreReady)
            statusLine("eventLoopRunning", sessionDiagnosticsManager.eventLoopRunning ? "true" : "false", isPositive: sessionDiagnosticsManager.eventLoopRunning)
            statusLine("mdnsStartedAfterCoreReady", mdnsStartedAfterCoreReady ? "true" : "false", isPositive: mdnsStartedAfterCoreReady)
            statusLine("waitingForPcTrust", waitingForPcTrust ? "true" : "false", isWarning: waitingForPcTrust)
            statusLine("decoderAutomationState", sessionDiagnosticsManager.decoderAutomationState.description)
            statusLine("decoderReady", sessionDiagnosticsManager.decoderReady ? "true" : "false", isPositive: sessionDiagnosticsManager.decoderReady)
            statusLine("decoderConfigEventSeen", sessionDiagnosticsManager.decoderConfigEventSeen ? "true" : "false", isPositive: sessionDiagnosticsManager.decoderConfigEventSeen)
            statusLine("frameCount", "\(sessionDiagnosticsManager.frameCount)", isPositive: sessionDiagnosticsManager.frameCount > 0)
            statusLine("totalBytes", "\(sessionDiagnosticsManager.totalBytes)", isPositive: sessionDiagnosticsManager.totalBytes > 0)

            if sessionDiagnosticsManager.frameCount == 0 && hudIndicatesStreamWillBeginSoon {
                Text("PC connected, but no frames have arrived yet.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if sessionDiagnosticsManager.frameCount > 0 && !sessionDiagnosticsManager.decoderConfigEventSeen {
                Text("Frames are arriving, but decoder config has not been seen yet.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func statusLine(
        _ title: String,
        _ value: String,
        isPositive: Bool = false,
        isWarning: Bool = false
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title + ":")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption2)
                .foregroundStyle(isPositive ? .green : (isWarning ? .orange : .secondary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var hudIndicatesStreamWillBeginSoon: Bool {
        if lastHudMessageContainsStreamWillBeginSoon(sessionDiagnosticsManager.lastFullHudMessage) {
            return true
        }

        return sessionDiagnosticsManager.recentUniqueHudMessages.contains {
            lastHudMessageContainsStreamWillBeginSoon($0)
        }
    }

    private func lastHudMessageContainsStreamWillBeginSoon(_ message: String?) -> Bool {
        message?.range(of: "The stream will begin soon", options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    @MainActor
    private func startHeadsetSession() async {
        guard !isStartingHeadsetSession else { return }

        isStartingHeadsetSession = true
        headsetSessionStartMode = "automatic"
        mdnsStartedAfterCoreReady = false
        waitingForPcTrust = false
        headsetSessionMessage = nil
        headsetSessionError = nil

        defer {
            isStartingHeadsetSession = false
        }

        guard !coreTestsRequireRestart else {
            headsetSessionError = "Restart the app before running another ALVR core test."
            return
        }

        var resolvedClientInfo = clientInfoResult
        if resolvedClientInfo?.success != true {
            headsetSessionMessage = "Loading ALVR Client Info before starting the core."
            let loadedInfo = ALVRClientCoreBridge.shared.loadClientInfo()
            clientInfoResult = loadedInfo
            resolvedClientInfo = loadedInfo
        }

        guard let resolvedClientInfo, resolvedClientInfo.success else {
            headsetSessionError = "Load ALVR Client Info failed. The ALVR headset session was not started."
            return
        }

        headsetSessionMessage = "Starting ALVR core, decoder callback, and event loop before mDNS broadcast."
        sessionDiagnosticsManager.start(clientInfo: resolvedClientInfo)

        guard await waitForSessionDiagnosticsEventLoop() else {
            headsetSessionError = "ALVR event loop did not reach Running state. mDNS broadcast was not started."
            return
        }

        headsetSessionMessage = "ALVR event loop is running. Starting mDNS broadcast."
        await mdnsBroadcaster.start(clientInfo: resolvedClientInfo)
        mdnsStartedAfterCoreReady = true
        waitingForPcTrust = true
        headsetSessionMessage = "Now open ALVR Streamer on PC and Trust / Connect this headset."
    }

    @MainActor
    private func stopHeadsetSession() {
        headsetSessionMessage = "Stopping ALVR headset session."
        waitingForPcTrust = false
        mdnsStartedAfterCoreReady = false
        sessionDiagnosticsManager.stop()
        mdnsBroadcaster.stop()
    }

    @MainActor
    private func waitForSessionDiagnosticsEventLoop() async -> Bool {
        for _ in 0..<100 {
            if sessionDiagnosticsManager.eventLoopRunning {
                return true
            }
            if !sessionDiagnosticsManager.isRunning && !sessionDiagnosticsManager.isStopping {
                return false
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return sessionDiagnosticsManager.eventLoopRunning
    }

    private func displayHudMessage(_ message: String) -> String {
        let limit = 1_000
        guard message.count > limit else {
            return message
        }

        return String(message.prefix(limit)) + "\n[truncated: showing first \(limit) of \(message.count) characters]"
    }

    private func debugPreview(for message: String) -> String {
        let previewLimit = 160
        let preview = String(message.prefix(previewLimit))
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        if message.count > previewLimit {
            return preview + " [preview truncated]"
        }
        return preview
    }

    private func hudMessageText(_ message: String) -> some View {
        Text(displayHudMessage(message))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .lineLimit(nil)
            .textSelection(.enabled)
    }

    private func diagnosticMessages(_ messages: [String]) -> some View {
        ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    private func hudMessages(_ messages: [String]) -> some View {
        ForEach(Array(messages.enumerated()), id: \.offset) { _, hudMessage in
            hudMessageText(hudMessage)
        }
    }

    private func copyDiagnosticsSummary() {
        let summary = makeDiagnosticsSummary()
        UIPasteboard.general.string = summary
        lastCopiedAt = Date()

        if UIPasteboard.general.string == summary {
            copyStatusMessage = "Copied ALVR diagnostics to clipboard (\(summary.count) characters)."
        } else {
            copyStatusMessage = "Failed to verify clipboard contents."
        }
    }

    private func makeDiagnosticsSummary() -> String {
        var lines: [String] = []

        func section(_ title: String) {
            if !lines.isEmpty {
                lines.append("")
            }
            lines.append("## \(title)")
        }

        func line(_ key: String, _ value: Any?) {
            lines.append("\(key): \(stringValue(value))")
        }

        func list(_ key: String, _ values: [String]) {
            line(key, values.isEmpty ? "[]" : values.joined(separator: ", "))
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let hudMessagesForSummary = allHudMessagesForSummary()
        let hudText = hudMessagesForSummary.joined(separator: "\n")
        let hudLower = hudText.lowercased()
        let decoderConfigSnapshot = sessionDiagnosticsManager.decoderConfigSnapshot
        let videoToolboxDecoderCreationResult = sessionDiagnosticsManager.videoToolboxDecoderCreationResult
        let videoToolboxFrameFeedSummary = sessionDiagnosticsManager.videoToolboxFrameFeedSummary
        let eventTagNames = sessionDiagnosticsManager.eventTagNames

        section("Basic Info")
        line("Timestamp", now)
        line("App / target", "Moonlight Vision / Moonlight XrOS")
        line("Branch", "unknown at runtime")
        line("ALVR HUD version", alvrHUDVersion(from: hudMessagesForSummary) ?? "unknown")
        line("Hostname", mdnsBroadcaster.activeHostname.isEmpty ? clientInfoResult?.rawHostname : mdnsBroadcaster.activeHostname)
        line("Device ID", firstNonEmpty(mdnsBroadcaster.deviceId, clientInfoResult?.deviceId))
        line("Service type", firstNonEmpty(mdnsBroadcaster.serviceType, clientInfoResult?.serviceType))
        line("Protocol ID", firstNonEmpty(mdnsBroadcaster.protocolId, clientInfoResult?.protocolId))

        section("Network / mDNS")
        line("mDNS broadcaster state", mdnsBroadcaster.state.description)
        line("Listener state", mdnsBroadcaster.listenerStateDescription)
        line("Listener ready", mdnsBroadcaster.listenerReady)
        line("Service name", mdnsBroadcaster.serviceName)
        line("Service type", mdnsBroadcaster.serviceType)
        line("Device ID", mdnsBroadcaster.deviceId)
        line("Protocol ID", mdnsBroadcaster.protocolId)
        line("Active listener port", mdnsBroadcaster.activePort)
        line("Port description", mdnsBroadcaster.portDescription)
        line("Recommended manual address", mdnsBroadcaster.recommendedManualConnectionAddress)
        list("Local IPv4 candidates", mdnsBroadcaster.localIPv4Candidates)
        list("Ignored IPv4 candidates", mdnsBroadcaster.ignoredIPv4Candidates)
        line("Last mDNS error", mdnsBroadcaster.lastError)
        line("Listener start time", mdnsBroadcaster.listenerStartTimeDescription)
        line("Listener restart count", mdnsBroadcaster.listenerRestartCount)
        line("TXT record", mdnsBroadcaster.txtRecordDescription)
        line("Port changed warning", mdnsBroadcaster.listenerPortChangedWarning)

        section("Session State")
        line("Session diagnostics state", sessionDiagnosticsManager.state.description)
        line("Headset session start mode", headsetSessionStartMode)
        line("ALVR core ready", sessionDiagnosticsManager.alvrCoreReady)
        line("Event loop running", sessionDiagnosticsManager.eventLoopRunning)
        line("mDNS started after core ready", mdnsStartedAfterCoreReady)
        line("Waiting for PC trust", effectiveWaitingForPcTrust)
        line("Requires app restart", sessionDiagnosticsManager.requiresAppRestart)
        line("Last step", sessionDiagnosticsManager.lastStep)
        line("Last error", firstNonEmpty(sessionDiagnosticsManager.errorMessage, headsetSessionError))
        line("Elapsed seconds", sessionDiagnosticsManager.elapsedSeconds)
        line("Session start time", "not tracked in UI state")
        line("Last event time", "not tracked in UI state")
        line("Last frame received time", "not tracked in UI state")
        line("Last decoded frame timestamp ns", videoToolboxFrameFeedSummary?.lastDecodedTimestampNs)
        line("Seconds since last frame", "not tracked in UI state")
        line("Seconds since last event", "not tracked in UI state")
        line("Headset session message", headsetSessionMessage)
        line("Lifecycle warning", sessionDiagnosticsManager.lifecycleWarningMessage)

        section("Event Counters")
        line("Streaming started count", countEvent("STREAMING_STARTED", in: eventTagNames))
        line("Streaming stopped count", countEvent("STREAMING_STOPPED", in: eventTagNames))
        line("Decoder config event count", countEvent("DECODER_CONFIG", in: eventTagNames))
        line("HUD message update count", countEvent("HUD_MESSAGE_UPDATED", in: eventTagNames))
        line("Real-time config event count", countEvent("REAL_TIME_CONFIG", in: eventTagNames))
        line("Haptics event count", countEvent("HAPTICS", in: eventTagNames))
        list("Event tag names", eventTagNames)
        line("Event tag raw values", sessionDiagnosticsManager.eventTagRawValues.map(String.init).joined(separator: ", "))

        section("HUD Messages")
        line("Last full HUD message", sessionDiagnosticsManager.lastFullHudMessage)
        line("Last full HUD message length", sessionDiagnosticsManager.lastFullHudMessageLength)
        line("Last full HUD message truncated", sessionDiagnosticsManager.lastFullHudMessageIsTruncated)
        list("Recent unique HUD messages", sessionDiagnosticsManager.recentUniqueHudMessages)
        line("trustRequired", containsAny(hudLower, ["trust", "trusted", "untrusted"]))
        line("successfulConnectionSeen", successfulConnectionSeen)
        line("connectionResetByPeerSeen", containsAny(hudLower, ["connection reset by peer", "reset by peer"]))
        line("resourceTemporarilyUnavailableSeen", containsAny(hudLower, ["resource temporarily unavailable"]))
        line("streamerRestartSeen", containsAny(hudLower, ["streamer restart", "restart streamer", "restarting"]))
        line("inferredConnectionStage", inferredConnectionStage(from: hudLower))

        section("Decoder Automation")
        line("Decoder automation state", sessionDiagnosticsManager.decoderAutomationState.description)
        line("Decoder config source", sessionDiagnosticsManager.decoderConfigSource)
        line("Decoder generation", sessionDiagnosticsManager.decoderGeneration)
        line("Decoder ready", sessionDiagnosticsManager.decoderReady)
        line("Decoder created automatically", sessionDiagnosticsManager.decoderCreatedAutomatically)
        line("Last rebuild reason", sessionDiagnosticsManager.lastRebuildReason)
        line("Last config source", sessionDiagnosticsManager.lastConfigSource)
        line("Auto decoder creation status", sessionDiagnosticsManager.autoDecoderCreationStatus)
        line("Parameter sets ready", sessionDiagnosticsManager.parameterSetsReady)
        line("VideoToolbox ready", sessionDiagnosticsManager.videoToolboxReady)
        list("Missing decoder prerequisites", sessionDiagnosticsManager.missingDecoderPrerequisites)
        line("Last decoder automation message", sessionDiagnosticsManager.lastDecoderAutomationMessage)
        line("Keyframe request available", sessionDiagnosticsManager.keyframeRequestAvailable)
        line("Keyframe request pending", sessionDiagnosticsManager.keyframeRequestPending)
        line("Keyframe request triggered", sessionDiagnosticsManager.keyframeRequestTriggered)
        line("Keyframe request count", sessionDiagnosticsManager.keyframeRequestCount)
        line("Frames since keyframe request", sessionDiagnosticsManager.framesSinceKeyframeRequest)
        line("Seconds since keyframe request", sessionDiagnosticsManager.secondsSinceKeyframeRequest)
        line("Keyframe request message", sessionDiagnosticsManager.keyframeRequestMessage)
        line("Decode-test IDR request available", sessionDiagnosticsManager.decodeTestIdrRequestAvailable)
        line("Decode-test IDR request pending", sessionDiagnosticsManager.decodeTestIdrRequestPending)
        line("Decode-test IDR request triggered", sessionDiagnosticsManager.decodeTestIdrRequestTriggered)
        line("Decode-test IDR request count", sessionDiagnosticsManager.decodeTestIdrRequestCount)
        line("Frames since decode-test IDR request", sessionDiagnosticsManager.framesSinceDecodeTestIdrRequest)
        line("Seconds since decode-test IDR request", sessionDiagnosticsManager.secondsSinceDecodeTestIdrRequest)
        line("Decode-test IDR request message", sessionDiagnosticsManager.decodeTestIdrRequestMessage)
        line("Decode-test IDR request disabled reason", sessionDiagnosticsManager.decodeTestIdrRequestDisabledReason)

        section("NAL / Frame Metadata")
        line("Frame count", sessionDiagnosticsManager.frameCount)
        line("Total bytes", sessionDiagnosticsManager.totalBytes)
        line("Last timestamp ns", sessionDiagnosticsManager.lastTimestampNs)
        line("Min buffer size", sessionDiagnosticsManager.minBufferSize)
        line("Max buffer size", sessionDiagnosticsManager.maxBufferSize)
        line("Codec guess", sessionDiagnosticsManager.codecGuess)
        line("NAL unit count", sessionDiagnosticsManager.nalUnitCount)
        line("HEVC VPS/SPS/PPS counts", "\(sessionDiagnosticsManager.hevcVpsCount)/\(sessionDiagnosticsManager.hevcSpsCount)/\(sessionDiagnosticsManager.hevcPpsCount)")
        line("HEVC IDR / CRA counts", "\(sessionDiagnosticsManager.hevcIdrCount)/\(sessionDiagnosticsManager.hevcCraCount)")
        line("HEVC TRAIL / slice / non-IDR counts", "\(sessionDiagnosticsManager.hevcTrailCount)/\(sessionDiagnosticsManager.hevcSliceCount)/\(sessionDiagnosticsManager.hevcNonIdrCount)")
        line("H264 SPS/PPS/IDR/non-IDR counts", "\(sessionDiagnosticsManager.h264SpsCount)/\(sessionDiagnosticsManager.h264PpsCount)/\(sessionDiagnosticsManager.h264IdrCount)/\(sessionDiagnosticsManager.h264NonIdrCount)")
        line("SEI count", sessionDiagnosticsManager.seiCount)
        line("Has parameter sets", sessionDiagnosticsManager.hasParameterSets)
        line("Has IDR", sessionDiagnosticsManager.hasIdr)
        list("First NAL types", sessionDiagnosticsManager.firstNalTypes)
        line("First frame prefix hex", sessionDiagnosticsManager.firstFramePrefixHex)
        line("Last frame prefix hex", sessionDiagnosticsManager.lastFramePrefixHex)

        section("Decoder Config Snapshot")
        line("Decoder config event seen", sessionDiagnosticsManager.decoderConfigEventSeen)
        line("Attempted", decoderConfigSnapshot?.attempted)
        line("Success", decoderConfigSnapshot?.success)
        line("Size", decoderConfigSnapshot?.size)
        line("Prefix hex", decoderConfigSnapshot?.prefixHex)
        line("ASCII preview", decoderConfigSnapshot?.asciiPreview)
        line("Config codec guess", decoderConfigSnapshot?.configCodecGuess)
        line("Config NAL count", decoderConfigSnapshot?.configNalUnitCount)
        line("Config HEVC VPS/SPS/PPS counts", optionalCounts(decoderConfigSnapshot?.hevcVpsCount, decoderConfigSnapshot?.hevcSpsCount, decoderConfigSnapshot?.hevcPpsCount))
        line("Config HEVC VPS/SPS/PPS sizes", optionalCounts(decoderConfigSnapshot?.hevcVpsSize, decoderConfigSnapshot?.hevcSpsSize, decoderConfigSnapshot?.hevcPpsSize))
        line("Config H264 SPS/PPS counts", optionalCounts(decoderConfigSnapshot?.h264SpsCount, decoderConfigSnapshot?.h264PpsCount))
        line("Config H264 SPS/PPS sizes", optionalCounts(decoderConfigSnapshot?.h264SpsSize, decoderConfigSnapshot?.h264PpsSize))
        line("Config parameter sets ready", decoderConfigSnapshot?.parameterSetsReady)
        line("Config VideoToolbox ready", decoderConfigSnapshot?.videoToolboxReady)
        list("Config NAL types", decoderConfigSnapshot?.configNalTypes ?? [])
        list("Config missing prerequisites", decoderConfigSnapshot?.missingDecoderPrerequisites ?? [])
        line("Config trigger reason", decoderConfigSnapshot?.triggerReason)
        list("Config messages", decoderConfigSnapshot?.messages ?? [])
        line("Config error", decoderConfigSnapshot?.errorDescription)

        section("VideoToolbox Diagnostics")
        line("HEVC decoder skeleton created", videoToolboxDecoderCreationResult?.success)
        line("Created format description", videoToolboxDecoderCreationResult?.createdFormatDescription)
        line("Created decompression session", videoToolboxDecoderCreationResult?.createdDecompressionSession)
        line("Format description status", videoToolboxDecoderCreationResult?.formatDescriptionStatus)
        line("Decompression session status", videoToolboxDecoderCreationResult?.decompressionSessionStatus)
        line("VPS/SPS/PPS sizes", optionalCounts(videoToolboxDecoderCreationResult?.vpsSize, videoToolboxDecoderCreationResult?.spsSize, videoToolboxDecoderCreationResult?.ppsSize))
        line("Frame feed test enabled", sessionDiagnosticsManager.frameFeedTestEnabled)
        line("Frame feed waiting for IDR/CRA", sessionDiagnosticsManager.frameFeedWaitingForIdr)
        line("Frame feed can copy frames", sessionDiagnosticsManager.frameFeedCanCopyFrames)
        line("Frame feed disabled reason", sessionDiagnosticsManager.frameFeedDisabledReason)
        line("Frame feed last skip reason", sessionDiagnosticsManager.frameFeedLastSkipReason)
        line("Frame feed copied after IDR request", sessionDiagnosticsManager.frameFeedCopiedAfterIdrRequest)
        line("Frame feed started at frame count", sessionDiagnosticsManager.frameFeedStartedAtFrameCount)
        line("Feed callback seen frame count", sessionDiagnosticsManager.feedCallbackSeenFrameCount)
        line("Feed callback saw IDR/CRA count", sessionDiagnosticsManager.feedCallbackSawIdrOrCraCount)
        list("Feed callback last NAL types", sessionDiagnosticsManager.feedCallbackLastNalTypes)
        line("Feed callback last decision", sessionDiagnosticsManager.feedCallbackLastDecision)
        line("Feed callback last skip reason", sessionDiagnosticsManager.feedCallbackLastSkipReason)
        line("Pending decode frame count", sessionDiagnosticsManager.pendingDecodeFrameCount)
        line("Copied frame count", videoToolboxFrameFeedSummary?.copiedFrameCount)
        line("Copied IDR frame count", videoToolboxFrameFeedSummary?.copiedIdrFrameCount)
        line("Copied CRA frame count", videoToolboxFrameFeedSummary?.copiedCraFrameCount)
        line("Submitted frame count", videoToolboxFrameFeedSummary?.submittedFrameCount)
        line("Submitted IDR frame count", videoToolboxFrameFeedSummary?.submittedIdrFrameCount)
        line("Submitted CRA frame count", videoToolboxFrameFeedSummary?.submittedCraFrameCount)
        line("Decoded frame count", videoToolboxFrameFeedSummary?.decodedFrameCount)
        line("Fed frame NAL types", videoToolboxFrameFeedSummary?.fedFrameNalTypes.joined(separator: ", "))
        line("Fed frame was random access", videoToolboxFrameFeedSummary?.fedFrameWasRandomAccess)
        line("Copied frame prefix hex", videoToolboxFrameFeedSummary?.copiedFramePrefixHex)
        line("Length-prefixed prefix hex", videoToolboxFrameFeedSummary?.convertedLengthPrefixedPrefixHex)
        line("Used synthetic PTS", videoToolboxFrameFeedSummary?.usedSyntheticPts)
        line("Sample PTS", videoToolboxFrameFeedSummary?.samplePtsDescription)
        line("Annex-B NAL count", videoToolboxFrameFeedSummary?.annexBNalCount)
        line("Converted NAL count", videoToolboxFrameFeedSummary?.convertedNalCount)
        line("Converted sample size", videoToolboxFrameFeedSummary?.convertedSampleSize)
        line("First converted NAL length", videoToolboxFrameFeedSummary?.firstConvertedNalLength)
        line("Conversion error", videoToolboxFrameFeedSummary?.conversionError)
        line("Waited for async decode frames", videoToolboxFrameFeedSummary?.didWaitForAsynchronousFrames)
        line("Last decode status", videoToolboxFrameFeedSummary?.lastDecodeCallStatus)
        line("Last callback status", videoToolboxFrameFeedSummary?.lastCallbackStatus)
        line("Info flags", videoToolboxFrameFeedSummary?.lastInfoFlagsRawValue)
        line("Pixel buffer width", videoToolboxFrameFeedSummary?.lastPixelBufferWidth)
        line("Pixel buffer height", videoToolboxFrameFeedSummary?.lastPixelBufferHeight)
        line("Pixel format", videoToolboxFrameFeedSummary?.lastPixelFormat)
        line("Plane count", videoToolboxFrameFeedSummary?.lastPlaneCount)
        line("Bytes per row", videoToolboxFrameFeedSummary?.lastBytesPerRowByPlane.map(String.init).joined(separator: ", "))
        line("Has IOSurface", videoToolboxFrameFeedSummary?.lastHasIOSurface)
        line("Metal compatibility hint", videoToolboxFrameFeedSummary?.lastMetalCompatibilityHint)
        line("Did call alvr_report_frame_decoded", videoToolboxFrameFeedSummary?.didCallAlvrReportFrameDecoded ?? false)
        list("Decode errors", videoToolboxFrameFeedSummary?.decodeErrors ?? [])
        list("VideoToolbox creation messages", videoToolboxDecoderCreationResult?.messages ?? [])
        list("VideoToolbox frame feed messages", videoToolboxFrameFeedSummary?.messages ?? [])

        section("Smoke Test Results")
        list("Symbol smoke messages", symbolSmokeResult?.messages ?? [])
        line("Symbol smoke error", symbolSmokeResult?.errorDescription)
        list("Lifecycle smoke messages", lifecycleSmokeResult?.messages ?? [])
        line("Lifecycle smoke error", lifecycleSmokeResult?.errorDescription)
        list("Controlled resume HUD messages", controlledResumeSmokeResult?.hudMessages ?? [])
        list("Controlled resume messages", controlledResumeSmokeResult?.messages ?? [])
        line("Controlled resume error", controlledResumeSmokeResult?.errorDescription)

        section("Warnings / Current Diagnosis")
        warningsForSummary(hudLower: hudLower).forEach { lines.append("- \($0)") }

        return lines.joined(separator: "\n")
    }

    private func warningsForSummary(hudLower: String) -> [String] {
        var warnings: [String] = []

        if sessionDiagnosticsManager.streamingEventSeen && !sessionDiagnosticsManager.decoderConfigEventSeen {
            warnings.append("Streaming started, but DECODER_CONFIG was not observed.")
        }
        let configProvidesParameterSets = sessionDiagnosticsManager.decoderReady
            || sessionDiagnosticsManager.decoderConfigSnapshot?.parameterSetsReady == true
        if sessionDiagnosticsManager.frameCount > 0
            && sessionDiagnosticsManager.hevcVpsCount == 0
            && sessionDiagnosticsManager.hevcSpsCount == 0
            && sessionDiagnosticsManager.hevcPpsCount == 0
            && !configProvidesParameterSets {
            warnings.append("HEVC frames are arriving, but VPS/SPS/PPS are missing.")
        } else if sessionDiagnosticsManager.frameCount > 0
                    && sessionDiagnosticsManager.hevcVpsCount == 0
                    && sessionDiagnosticsManager.hevcSpsCount == 0
                    && sessionDiagnosticsManager.hevcPpsCount == 0
                    && configProvidesParameterSets {
            warnings.append("In-band VPS/SPS/PPS not present in video frames, but decoder config provides VPS/SPS/PPS.")
        }
        if streamingStoppedCount > 0 && containsAny(hudLower, ["connection reset by peer", "reset by peer"]) {
            warnings.append("PC ALVR Streamer closed the connection.")
        }
        if containsAny(hudLower, ["microphone not found", "mic not found", "microphone"]) {
            warnings.append("Disable Headset microphone in ALVR Streamer until microphone capture is implemented.")
        }
        if mdnsBroadcaster.listenerReady && !sessionDiagnosticsManager.eventLoopRunning {
            warnings.append("PC can discover headset, but ALVR core is not running.")
        }
        if sessionDiagnosticsManager.frameCount == 0 && containsAny(hudLower, ["the stream will begin soon"]) {
            warnings.append("PC connected, but no frames have arrived yet.")
        }
        if sessionDiagnosticsManager.frameCount > 0 && !sessionDiagnosticsManager.decoderConfigEventSeen {
            warnings.append("Frames are arriving, but decoder config has not been seen yet.")
        }
        if let listenerPortChangedWarning = mdnsBroadcaster.listenerPortChangedWarning {
            warnings.append(listenerPortChangedWarning)
        }
        if warnings.isEmpty {
            warnings.append("No high-priority ALVR diagnostic warnings inferred from current UI state.")
        }

        return warnings
    }

    private func allHudMessagesForSummary() -> [String] {
        var messages: [String] = []
        if let lastFullHudMessage = sessionDiagnosticsManager.lastFullHudMessage {
            messages.append(lastFullHudMessage)
        }
        messages.append(contentsOf: sessionDiagnosticsManager.recentUniqueHudMessages)
        messages.append(contentsOf: sessionDiagnosticsManager.hudMessages)
        if let controlledResumeSmokeResult {
            messages.append(contentsOf: controlledResumeSmokeResult.hudMessages)
        }
        return messages
    }

    private func alvrHUDVersion(from messages: [String]) -> String? {
        messages.first { $0.localizedCaseInsensitiveContains("ALVR v") }
    }

    private func inferredConnectionStage(from hudLower: String) -> String {
        if containsAny(hudLower, ["successful connection", "stream will begin soon"]) {
            return "PC connected; waiting for stream frames or decoder path."
        }
        if containsAny(hudLower, ["trust", "trusted", "untrusted"]) {
            return "Trust / pairing required or in progress."
        }
        if containsAny(hudLower, ["connection reset", "reset by peer"]) {
            return "PC connection closed/reset."
        }
        if sessionDiagnosticsManager.frameCount > 0 {
            return "Video frames are arriving."
        }
        if sessionDiagnosticsManager.streamingEventSeen {
            return "Streaming event observed."
        }
        if mdnsBroadcaster.listenerReady {
            return "mDNS advertising is ready; waiting for PC discovery/connect."
        }
        return "Idle or unknown."
    }

    private func countEvent(_ needle: String, in eventTagNames: [String]) -> Int {
        eventTagNames.filter { $0.localizedCaseInsensitiveContains(needle) }.count
    }

    private func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private func firstNonEmpty(_ values: String?...) -> String? {
        values.first { value in
            guard let value else { return false }
            return !value.isEmpty
        } ?? nil
    }

    private func optionalCounts(_ values: Any?...) -> String {
        values.map { stringValue($0) }.joined(separator: "/")
    }

    private func stringValue(_ value: Any?) -> String {
        guard let value else { return "nil" }
        if let value = value as? String {
            return value.isEmpty ? "empty" : value
        }
        if let value = value as? Bool {
            return value ? "true" : "false"
        }
        return String(describing: value)
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
