// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import SwiftUI

struct ScratchpadSettingsSection: View {
    @Bindable var settings: SettingsStore
    @Bindable var controller: WMController
    @State private var editingSlot: ScratchpadSlotEdit?

    var body: some View {
        Section {
            ForEach(Array(ScratchpadIndex.range), id: \.self) { slot in
                ScratchpadSlotRow(
                    slot: slot,
                    label: settings.scratchpadLabel(for: slot),
                    mode: settings.scratchpadMode(for: slot),
                    apps: ruleApps(for: slot),
                    onEdit: {
                        editingSlot = ScratchpadSlotEdit(
                            slot: slot,
                            label: settings.scratchpadLabel(for: slot) ?? "",
                            mode: settings.scratchpadMode(for: slot)
                        )
                    }
                )
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
        .sheet(item: $editingSlot) { edit in
            ScratchpadSlotEditSheet(
                edit: edit,
                apps: ruleApps(for: edit.slot),
                onSave: { saved in
                    settings.setScratchpadLabel(saved.label, for: saved.slot)
                    settings.setScratchpadMode(saved.mode, for: saved.slot)
                    controller.requestWorkspaceBarRefresh()
                    editingSlot = nil
                },
                onCancel: { editingSlot = nil }
            )
        }
    }

    private func ruleApps(for slot: Int) -> [String] {
        settings.appRules.filter { $0.validScratchpadSlot == slot }.map(\.displayLabel)
    }
}

struct ScratchpadSlotEdit: Identifiable {
    let slot: Int
    var label: String
    var mode: ScratchpadMode?

    var id: Int {
        slot
    }
}

private struct ScratchpadSlotRow: View {
    let slot: Int
    let label: String?
    let mode: ScratchpadMode?
    let apps: [String]
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Text(verbatim: "SP \(slot)")
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
                if let label {
                    Text(verbatim: label)
                        .font(.body.weight(.medium))
                } else {
                    Text(verbatim: "No label")
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            .frame(minWidth: 120, alignment: .leading)

            Divider()
                .frame(height: 24)

            Text(verbatim: mode.map(ScratchpadSlotEditSheet.title) ?? "Default")
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(mode == nil ? 0.04 : 0.12))
                .cornerRadius(4)

            if !apps.isEmpty {
                Divider()
                    .frame(height: 24)
                Text(verbatim: apps.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            Button(action: onEdit) {
                Label {
                    Text(verbatim: "Edit scratchpad \(slot)")
                } icon: {
                    Image(systemName: "pencil.circle")
                }
                .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .help(Text(verbatim: "Rename scratchpad \(slot) or change its mode"))
        }
        .padding(.vertical, 4)
    }
}

struct ScratchpadSlotEditSheet: View {
    @State private var edit: ScratchpadSlotEdit
    let apps: [String]
    let onSave: (ScratchpadSlotEdit) -> Void
    let onCancel: () -> Void

    init(
        edit: ScratchpadSlotEdit,
        apps: [String],
        onSave: @escaping (ScratchpadSlotEdit) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _edit = State(initialValue: edit)
        self.apps = apps
        self.onSave = onSave
        self.onCancel = onCancel
    }

    static func title(_ mode: ScratchpadMode) -> String {
        switch mode {
        case .persistent: "Persistent"
        case .volatile: "Volatile"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField(text: $edit.label, prompt: Text(verbatim: "Shown in the workspace bar")) {
                        Text(verbatim: "Label")
                    }
                    Picker(selection: $edit.mode) {
                        Text(verbatim: "Default").tag(ScratchpadMode?.none)
                        Text(verbatim: "Persistent").tag(ScratchpadMode?.some(.persistent))
                        Text(verbatim: "Volatile").tag(ScratchpadMode?.some(.volatile))
                    } label: {
                        Text(verbatim: "Mode")
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text(verbatim: "Scratchpad \(edit.slot)")
                } footer: {
                    Text(verbatim: modeExplanation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    if apps.isEmpty {
                        Text(
                            verbatim: "No app rule assigns windows to this slot. Add one in App Rules with Assign to Scratchpad."
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    } else {
                        ForEach(apps, id: \.self) { app in
                            Text(verbatim: app)
                        }
                    }
                } header: {
                    Text(verbatim: "Apps")
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button(action: onCancel) {
                    Text(verbatim: "Cancel")
                }
                .keyboardShortcut(.cancelAction)
                Button {
                    onSave(edit)
                } label: {
                    Text(verbatim: "Save")
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 420, height: 360)
    }

    private var modeExplanation: String {
        switch edit.mode {
        case .persistent:
            "Windows rejoin this slot after OmniWM restarts, and are minimized when OmniWM quits."
        case .volatile:
            "Windows are forgotten on restart, and closed when OmniWM quits. Their apps keep running."
        case nil:
            "Upstream behaviour: windows are forgotten on restart and left as they are when OmniWM quits."
        }
    }
}
