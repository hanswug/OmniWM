// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import Foundation
@testable import OmniWM
import XCTest

@MainActor
final class PaddingPresetAndPlacementTests: XCTestCase {
    private let presets = [
        SettingsExport.PaddingPreset(name: "Edge", top: 11, bottom: 11, left: 11, right: 11),
        SettingsExport.PaddingPreset(name: "Tall", top: 333, bottom: 11, left: 11, right: 11),
        SettingsExport.PaddingPreset(name: "Single", top: 444, bottom: 11, left: 555, right: 555)
    ]

    func testPresetsRoundTripAndTheActiveOneIsDerivedFromTheGaps() {
        let settings = makeSettings()
        settings.gaps.paddingPresets = presets
        XCTAssertNil(settings.gaps.activePaddingPresetIndex)

        let exported = settings.toExport().gaps
        XCTAssertEqual(exported.presets, presets)
        let restored = GapSettings()
        restored.apply(exported)
        XCTAssertEqual(restored.paddingPresets, presets)

        settings.gaps.outerGapTop = 333
        settings.gaps.outerGapBottom = 11
        settings.gaps.outerGapLeft = 11
        settings.gaps.outerGapRight = 11
        XCTAssertEqual(settings.gaps.activePaddingPresetIndex, 1)

        settings.gaps.paddingPresets = []
        XCTAssertNil(settings.toExport().gaps.presets)
    }

    func testCyclingStartsAtTheFirstPresetAndWrapsAround() {
        let controller = WMController(settings: makeSettings())
        controller.settings.gaps.paddingPresets = presets

        controller.cyclePaddingPreset()
        XCTAssertEqual(controller.settings.gaps.activePaddingPresetIndex, 0)
        controller.cyclePaddingPreset()
        controller.cyclePaddingPreset()
        XCTAssertEqual(controller.settings.gaps.activePaddingPresetIndex, 2)
        XCTAssertEqual(controller.settings.gaps.outerGapLeft, 555)
        controller.cyclePaddingPreset()
        XCTAssertEqual(controller.settings.gaps.activePaddingPresetIndex, 0)
    }

    func testCyclingWithoutPresetsLeavesTheGapsAlone() {
        let controller = WMController(settings: makeSettings())
        let before = controller.settings.toExport().gaps
        controller.cyclePaddingPreset()
        controller.setPaddingPreset(at: 3)
        XCTAssertEqual(controller.settings.toExport().gaps, before)
    }

    func testADisplayWithItsOwnGapsKeepsThemAndSaysSo() throws {
        let previous = CommandFeedback.present
        var shown: [CommandFeedbackMessage] = []
        CommandFeedback.present = { shown.append($0) }
        defer { CommandFeedback.present = previous }
        let controller = WMController(settings: makeSettings())
        controller.settings.commandFeedback = true
        controller.settings.gaps.paddingPresets = presets
        let frame = CGRect(x: 0, y: 0, width: 1710, height: 1112)
        let monitor = Monitor(
            id: .init(displayId: 77), displayId: 77, frame: frame, visibleFrame: frame,
            hasNotch: true, name: "Built-in Retina Display"
        )
        controller.workspaceManager.applyMonitorConfigurationChange([monitor])
        controller.settings.gaps.update(
            MonitorGapSettings(monitorName: monitor.name, outerGapLeft: 8, outerGapTop: 8),
            for: monitor
        )
        let before = controller.settings.toExport().gaps

        controller.cyclePaddingPreset()
        controller.setPaddingPreset(at: 2)

        XCTAssertEqual(controller.settings.toExport().gaps, before)
        XCTAssertEqual(shown, [CommandFeedback.ownPadding("Built-in"), CommandFeedback.ownPadding("Built-in")])
        XCTAssertEqual(controller.shellForkStatus(on: monitor.id).ownPadding, "Built-in")

        controller.settings.gaps.remove(for: monitor)
        XCTAssertNil(controller.shellForkStatus(on: monitor.id).ownPadding)
        controller.cyclePaddingPreset()
        XCTAssertEqual(controller.settings.gaps.activePaddingPresetIndex, 0)
    }

    func testPlacementCyclesThroughEveryPlacementAndReachesTheEngine() {
        let controller = WMController(settings: makeSettings())
        controller.enableNiriLayout()
        var seen: [NewWindowPlacement] = []
        for _ in NewWindowPlacement.allCases {
            controller.cycleNewWindowPlacement()
            seen.append(controller.settings.niri.newWindowPlacement)
            XCTAssertEqual(controller.niriEngine?.newWindowPlacement, controller.settings.niri.newWindowPlacement)
        }
        XCTAssertEqual(Set(seen), Set(NewWindowPlacement.allCases))
        XCTAssertEqual(seen.last, .right)

        controller.setNewWindowPlacement(.first)
        XCTAssertEqual(controller.settings.toExport().niri.newWindowPlacement, .first)
    }

    private func makeSettings() -> SettingsStore {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("OmniWMPaddingPresetTests-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return SettingsStore(
            persistence: SettingsFilePersistence(
                directory: root.appendingPathComponent("config", isDirectory: true),
                startWatching: false,
                deferSaves: false
            ),
            runtimeState: RuntimeStateStore(
                directory: root.appendingPathComponent("state", isDirectory: true),
                deferSaves: false
            ),
            autosaveEnabled: false
        )
    }
}
