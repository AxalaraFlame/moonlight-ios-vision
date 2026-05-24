//
//  AppsView.swift
//  Moonlight Vision
//
//  Created by Alex Haugland on 1/27/24.
//  Updated by Lumanaire (RikuKunMS2) on 4/26/26.
//  Notice: If you are missing from the contributor list, please contact Lumanaire (RikuKunMS2).
//
//  Copyright © 2024 Moonlight Game Streaming Project. All rights reserved.
//

import Foundation
import SwiftUI

struct AppsView: View {
    @EnvironmentObject private var viewModel: MainViewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State private var nowLoading: String?
    @State private var nowLoadingTimeout: Task<Void, Never>?
    @State private var streamModeOverlayApp: TemporaryApp?
    @State private var alvrConnectionApp: TemporaryApp?
    
    @Binding
    public var host: TemporaryHost
    
    var body: some View {
        Group {
            if viewModel.activelyStreaming {
                // When stream running in background, show Resume + Stop instead of app list
                streamInProgressView
            } else {
                let sortedApps = host.appList.sorted(by: { ($0.name ?? "") < ($1.name ?? "") })
                List {
                    ForEach(sortedApps, id: \.id) { app in
                        HStack {
                            if (nowLoading == (app.id ?? app.name)) {
                                ProgressView()
                            }
                            AppButtonView(host: host, app: app) {
                                streamModeOverlayApp = app
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(host.name)
        .onAppear() {
            guard !viewModel.activelyStreaming else { return }
            Task { await viewModel.refreshAppsFor(host: host) }
        }
        .alert(viewModel.localized("close_previous_window"), isPresented: $viewModel.showClassicWindowCloseAlert) {
            Button(viewModel.localized("got_it"), role: .cancel) {}
        } message: {
            Text(viewModel.localized("close_previous_window_message"))
        }
        .alert(viewModel.localized("close_realitykit_window"), isPresented: $viewModel.showRealityWindowCloseAlert) {
            Button(viewModel.localized("got_it"), role: .cancel) {}
        } message: {
            Text(viewModel.localized("close_realitykit_window_message"))
        }
        .refreshable() {
            guard !viewModel.activelyStreaming else { return }
            await viewModel.refreshAppsFor(host: host)
        }
        .sheet(item: $streamModeOverlayApp) { app in
            StreamModeSelectionOverlay(
                app: app,
                onSelect: { mode in
                    streamModeOverlayApp = nil
                    if mode == .vr {
                        alvrConnectionApp = app
                    } else {
                        Task { await launchStreamWithMode(app: app, mode: mode) }
                    }
                },
                onDismiss: {
                    streamModeOverlayApp = nil
                }
            )
            .environmentObject(viewModel)
        }
        .sheet(item: $alvrConnectionApp) { app in
            ALVRConnectionView(app: app)
                .environmentObject(viewModel)
        }
    }
    
    /// Resume + Stop when stream is running in background (main pushed from Home)
    @ViewBuilder
    private var streamInProgressView: some View {
        VStack(spacing: 24) {
            Text(viewModel.localized("active_stream"))
                .font(.title2)
                .foregroundStyle(.secondary)
            
            // Resume - return to stream window via notification
            Button {
                Task { await resumeStreamFromMainMenu() }
            } label: {
                Label(viewModel.localized("resume_stream"), systemImage: "play.circle.fill")
                    .font(.title2)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            
            // Stop - full teardown (notification needed: stream view behind main may not receive shouldCloseStream)
            Button(role: .destructive) {
                Task { await stopStreamFromMainMenu() }
            } label: {
                Label(viewModel.localized("stop"), systemImage: "stop.circle.fill")
                    .font(.title2)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.bordered)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @MainActor
    private func handleStreamLaunch(for app: TemporaryApp, mode: StreamingMode) async {
        guard nowLoading == nil else { return }
        let appId = app.id ?? app.name
        nowLoading = appId
        startNowLoadingTimeout()

        // If stale lifecycle state remains after crown/app interruptions, wait briefly and recover.
        if viewModel.streamState != .idle {
            await viewModel.waitForTeardown(timeout: 1.2)
        }
        if viewModel.streamState != .idle {
            viewModel.forceResetStreamLifecycleIfNeeded()
        }
        if viewModel.activelyStreaming {
            clearNowLoading()
            return
        }

        let cooldown = viewModel.reconnectCooldownRemaining()
        if cooldown > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + cooldown + 0.05) {
                Task {
                    if viewModel.streamState != .idle {
                        await viewModel.waitForTeardown()
                    }
                    await openAppStream(app: app, mode: mode)
                }
            }
            return
        }

        if let stale = _UIKitStreamView.controllerReference.object {
            stale.stopStream()
            _UIKitStreamView.controllerReference.object = nil
        }
        await openAppStream(app: app, mode: mode)
    }

    @MainActor
    private func launchStreamWithMode(app: TemporaryApp, mode: StreamingMode) async {
        await handleStreamLaunch(for: app, mode: mode)
    }

    @MainActor
    private func resumeStreamFromMainMenu() async {
        NotificationCenter.default.post(name: Notification.Name("ResumeStreamFromMenu"), object: nil)

        // If stream window/space was closed by system gesture (e.g. crown),
        // no receiver may exist for ResumeStreamFromMenu. Reopen from saved config.
        if viewModel.activeXRStreamingMode == .vr {
            dismissWindow(id: "mainView")
            await openImmersiveSpace(id: "ALVRImmersiveSpace")
            return
        }

        guard let saved = viewModel.savedStreamConfigForResume else { return }
        if viewModel.streamState == .idle {
            viewModel.streamState = .starting
        }
        viewModel.activelyStreaming = true

        if viewModel.activeXRStreamingMode == .realityKitImmersive || (viewModel.streamSettings.renderer == .realitykit && viewModel.streamSettings.realitykitImmersiveMode) {
            dismissWindow(id: "mainView")
            _ = try? await openImmersiveSpace(id: "realitykitImmersiveSpace", value: saved)
        } else if viewModel.activeXRStreamingMode == .realityKitWindow || viewModel.streamSettings.renderer == .realitykit {
            dismissWindow(id: "classicStreamingWindow")
            openWindow(id: "realitykitStreamingWindow", value: saved)
            dismissWindow(id: "mainView")
        } else {
            dismissWindow(id: "realitykitStreamingWindow")
            openWindow(id: "classicStreamingWindow", value: saved)
            dismissWindow(id: "mainView")
        }
    }

    @MainActor
    private func stopStreamFromMainMenu() async {
        NotificationCenter.default.post(name: Notification.Name("RequestStreamCloseFromMainMenu"), object: nil)
        if viewModel.activeXRStreamingMode == .vr {
            await ALVRBackend().endSession(viewModel: viewModel)
            await dismissImmersiveSpace()
            return
        }

        viewModel.userDidRequestDisconnect()
        await viewModel.waitForTeardown(timeout: 6.5)
        if viewModel.streamState != .idle || viewModel.activelyStreaming {
            viewModel.forceResetStreamLifecycleIfNeeded()
        }
    }

    @MainActor
    private func openAppStream(app: TemporaryApp, mode: StreamingMode) async {
        let config: StreamConfiguration?
        if mode.usesALVRBackend {
            config = await VRStreaming().prepare(app: app, viewModel: viewModel)
        } else {
            config = await FlatStreaming().prepare(app: app, mode: mode, viewModel: viewModel)
        }

        guard let config else {
            clearNowLoading()
            return
        }

        // Dismiss existing stream windows before opening new one
        dismissWindow(id: "realitykitStreamingWindow")
        dismissWindow(id: "classicStreamingWindow")

        switch mode.destination {
        case .immersiveSpace(let id):
            dismissWindow(id: "mainView")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                Task {
                    _ = try? await openImmersiveSpace(id: id, value: config)
                    await MainActor.run { clearNowLoading() }
                }
            }
        case .window(let id):
            Task {
                await dismissImmersiveSpace()
                await MainActor.run {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        openWindow(id: id, value: config)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        dismissWindow(id: "mainView")
                        clearNowLoading()
                    }
                }
            }
        }
    }

    private func clearNowLoading() {
        nowLoadingTimeout?.cancel()
        nowLoadingTimeout = nil
        nowLoading = nil
    }

    private func startNowLoadingTimeout() {
        nowLoadingTimeout?.cancel()
        nowLoadingTimeout = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if nowLoading != nil {
                    print("[AppsView] nowLoading safety timeout (5s)")
                    clearNowLoading()
                }
            }
        }
    }
}

struct AppButtonView: View {
    @EnvironmentObject private var viewModel: MainViewModel
    let host: TemporaryHost
    let app: TemporaryApp
    let action: () -> Void
    
    var body: some View {
        Button(app.name ?? viewModel.localized("unknown"), action: action)
            .badge(Text(app.id == host.currentGame ? viewModel.localized("running") : ""))
            .contextMenu {
                if app.id == host.currentGame {
                    Button {
                        let httpManager = HttpManager(host: app.host())
                        let httpResponse = HttpResponse()
                        let quitRequest = HttpRequest(for: httpResponse, with: httpManager?.newQuitAppRequest())
                        Task {
                            httpManager?.executeRequestSynchronously(quitRequest)
                        }
                    } label: {
                        Label(viewModel.localized("stop"), systemImage: "stop.circle")
                    }
                }
            }
    }
}
