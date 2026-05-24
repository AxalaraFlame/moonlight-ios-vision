//
//  StreamModeSelectionOverlay.swift
//  Moonlight Vision
//
//  Created by Lumanaire (RikuKunMS2).
//  Updated by Lumanaire (RikuKunMS2) on 4/26/26.
//  Notice: If you are missing from the contributor list, please contact Lumanaire (RikuKunMS2).
//
//  Overlay for selecting stream mode when launching.
//
//  Copyright © 2024 Moonlight Game Streaming Project. All rights reserved.
//

import SwiftUI

struct StreamModeSelectionOverlay: View {
    @EnvironmentObject private var viewModel: MainViewModel
    let app: TemporaryApp
    let onSelect: (StreamingMode) -> Void
    let onDismiss: () -> Void

    @State private var selectedMode: StreamingMode = .uiKitWindow

    var body: some View {
        VStack(spacing: 22) {
            Text(viewModel.localized("select_stream_mode"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(app.name ?? viewModel.localized("unknown"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker(viewModel.localized("stream_mode_picker"), selection: $selectedMode) {
                ForEach(StreamingMode.allCases) { mode in
                    Label(
                        viewModel.localized(mode.titleLocalizationKey),
                        systemImage: mode.iconName
                    )
                    .tag(mode)
                }
            }
            .pickerStyle(.segmented)

            SelectedStreamModeSummary(mode: selectedMode)
                .environmentObject(viewModel)

            HStack(spacing: 12) {
                Button(action: onDismiss) {
                    Text(viewModel.localized("cancel"))
                }
                .buttonStyle(.bordered)

                Button {
                    onSelect(selectedMode)
                } label: {
                    Label(viewModel.localized("launch_stream"), systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(width: 620)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct SelectedStreamModeSummary: View {
    @EnvironmentObject private var viewModel: MainViewModel
    let mode: StreamingMode

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: mode.iconName)
                .font(.system(size: 34, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var title: String {
        viewModel.localized(mode.titleLocalizationKey)
    }

    private var subtitle: String {
        viewModel.localized(mode.subtitleLocalizationKey)
    }
}
