// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import SwiftUI

struct ScratchpadSettingsSection: View {
    @Bindable var settings: SettingsStore
    @Bindable var controller: WMController

    var body: some View {
        Section {
            ForEach(Array(ScratchpadIndex.range), id: \.self) { slot in
                ScratchpadSlotRow(slot: slot, settings: settings, controller: controller)
            }
        } header: {
            Text(verbatim: "Scratchpads")
        } footer: {
            Text(
                verbatim: "Persistent slots keep their windows across restarts and minimize them when OmniWM quits. Volatile slots forget their windows and close them when OmniWM quits; the apps keep running. Choose which apps open in a slot in App Rules."
            )
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .id("Scratchpads")
    }
}

private struct ScratchpadSlotRow: View {
    let slot: Int
    @Bindable var settings: SettingsStore
    @Bindable var controller: WMController

    private var label: Binding<String> {
        Binding(
            get: { settings.scratchpadLabel(for: slot) ?? "" },
            set: { newValue in
                settings.setScratchpadLabel(newValue, for: slot)
                controller.requestWorkspaceBarRefresh()
            }
        )
    }

    private var mode: Binding<ScratchpadMode?> {
        Binding(
            get: { settings.scratchpadMode(for: slot) },
            set: { settings.setScratchpadMode($0, for: slot) }
        )
    }

    private var ruleApps: String {
        settings.appRules
            .filter { $0.validScratchpadSlot == slot }
            .map(\.displayLabel)
            .joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(verbatim: "\(slot)")
                    .monospacedDigit()
                    .frame(width: 20, alignment: .trailing)
                TextField(text: label, prompt: Text(verbatim: "Label")) {
                    Text(verbatim: "Label")
                }
                .labelsHidden()
                Picker(selection: mode) {
                    Text(verbatim: "Default").tag(ScratchpadMode?.none)
                    Text(verbatim: "Persistent").tag(ScratchpadMode?.some(.persistent))
                    Text(verbatim: "Volatile").tag(ScratchpadMode?.some(.volatile))
                } label: {
                    Text(verbatim: "Mode")
                }
                .labelsHidden()
                .frame(width: 130)
            }
            if !ruleApps.isEmpty {
                Text(verbatim: ruleApps)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 28)
            }
        }
    }
}
