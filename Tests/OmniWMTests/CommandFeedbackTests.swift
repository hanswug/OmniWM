// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import ApplicationServices
import Foundation
@testable import OmniWM
import XCTest

@MainActor
final class CommandFeedbackTests: XCTestCase {
    private var shown: [CommandFeedbackMessage] = []
    private let monitorFrame = CGRect(x: 0, y: 0, width: 2400, height: 1200)

    override func setUp() async throws {
        shown = []
        let previous = CommandFeedback.present
        CommandFeedback.present = { [weak self] message in self?.shown.append(message) }
        CommandFeedback.lastFocusedWindowLayout = nil
        addTeardownBlock { @MainActor in
            CommandFeedback.present = previous
            CommandFeedback.lastFocusedWindowLayout = nil
        }
    }

    func testNothingShowsWhileTheSettingIsOff() {
        let controller = WMController(settings: makeSettings())
        XCTAssertFalse(controller.settings.commandFeedback)
        controller.setVisibleContainerCount(3)
        controller.setNewWindowJoin(.tabbed)
        controller.toggleBorders()
        XCTAssertTrue(shown.isEmpty)
    }

    func testCommandsThatChangeHiddenStateShowWhatTheyChanged() {
        let controller = WMController(settings: makeSettings())
        controller.settings.commandFeedback = true
        controller.settings.gaps.paddingPresets = [
            SettingsExport.PaddingPreset(name: "Wide Tall", top: 333, bottom: 11, left: 11, right: 11)
        ]
        let bordersWereOn = controller.settings.borders.enabled

        controller.setVisibleContainerCount(3)
        controller.cyclePaddingPreset()
        controller.setNewWindowJoin(.stacked)
        controller.setNewWindowPlacement(.first)
        controller.toggleBorders()

        XCTAssertEqual(shown, [
            CommandFeedback.visibleContainers(3),
            CommandFeedback.paddingPreset("Wide Tall"),
            CommandFeedback.newWindowJoin(.stacked),
            CommandFeedback.newWindowPlacement(.first),
            CommandFeedback.borders(!bordersWereOn)
        ])
        XCTAssertEqual(shown.first?.text, "VC 3")
    }

    func testOnlyTheSameWindowFlippingFullscreenOrFullContainerShows() {
        let window = WindowToken(pid: 1, windowId: 1)
        let other = WindowToken(pid: 1, windowId: 2)
        let normal = FocusedWindowLayoutState(token: window, isFullscreen: false, isContainerFullPrimarySpan: false)
        let fullscreen = FocusedWindowLayoutState(token: window, isFullscreen: true, isContainerFullPrimarySpan: false)
        let fullSpan = FocusedWindowLayoutState(token: window, isFullscreen: false, isContainerFullPrimarySpan: true)
        let otherFullscreen = FocusedWindowLayoutState(
            token: other,
            isFullscreen: true,
            isContainerFullPrimarySpan: false
        )

        XCTAssertEqual(CommandFeedback.layoutChange(from: normal, to: fullscreen)?.text, "Fullscreen on")
        XCTAssertEqual(CommandFeedback.layoutChange(from: fullscreen, to: normal)?.text, "Fullscreen off")
        XCTAssertEqual(CommandFeedback.layoutChange(from: normal, to: fullSpan)?.text, "Full container on")
        XCTAssertEqual(CommandFeedback.layoutChange(from: fullSpan, to: normal)?.text, "Full container off")
        XCTAssertNil(CommandFeedback.layoutChange(from: normal, to: otherFullscreen))
        XCTAssertNil(CommandFeedback.layoutChange(from: nil, to: fullscreen))
        XCTAssertNil(CommandFeedback.layoutChange(from: normal, to: normal))
    }

    func testAShrinkPressStoppedByAKnownMinimumSaysSo() throws {
        let settings = makeSettings()
        settings.commandFeedback = true
        settings.borders.enabled = false
        settings.workspaceBar.enabled = false
        settings.gaps.size = 10
        settings.gaps.outerGapLeft = 0
        settings.gaps.outerGapRight = 0
        settings.gaps.outerGapTop = 0
        settings.gaps.outerGapBottom = 0
        let monitor = Monitor(
            id: .init(displayId: 1), displayId: 1, frame: monitorFrame, visibleFrame: monitorFrame,
            hasNotch: false, name: "Main"
        )
        settings.workspaces.configurations = [
            WorkspaceConfiguration(
                name: "1",
                monitorAssignment: .specificDisplay(OutputId(from: monitor)),
                layoutType: .niri
            )
        ]
        let controller = WMController(settings: settings)
        controller.setGapSize(10, publishChange: false)
        controller.workspaceManager.applyMonitorConfigurationChange([monitor])
        controller.workspaceManager.applySettings()
        controller.niriLayoutHandler.enableNiriLayout()
        controller.syncMonitorsToNiriEngine()
        let workspaceId = try XCTUnwrap(controller.workspaceManager.workspaceId(named: "1"))
        XCTAssertTrue(controller.workspaceManager.setActiveWorkspace(workspaceId, on: monitor.id))
        let tokens = (0 ..< 2).map { index in
            controller.workspaceManager.addWindow(
                AXWindowRef(element: AXUIElementCreateApplication(pid_t(870 + index)), windowId: 870 + index),
                pid: pid_t(870 + index),
                windowId: 870 + index,
                to: workspaceId
            )
        }
        let handle = try XCTUnwrap(controller.workspaceManager.handle(for: tokens[0]))
        _ = controller.workspaceManager.withBatchedLayoutBuild {
            controller.niriLayoutHandler.layoutWithNiriEngine(activeWorkspaces: [workspaceId])
        }

        controller.niriLayoutHandler.setWindowPrimarySpan(.adjustProportion(-10), target: .window(handle))
        var evidence = ObservedSizeEvidence()
        evidence.minSize = CGSize(width: 900, height: 1)
        XCTAssertTrue(controller.workspaceManager.setObservedSizeEvidence(evidence, for: tokens[0]))
        controller.niriLayoutHandler.noteRefusedMinimum(for: tokens[0])
        XCTAssertTrue(shown.isEmpty)

        controller.niriLayoutHandler.setWindowPrimarySpan(.adjustProportion(-10), target: .window(handle))

        XCTAssertEqual(shown, [CommandFeedback.sizeLimit(app: "Window", minimum: true, width: 900)])
        XCTAssertEqual(shown.first?.text, "Window: minimum 900")
    }

    private func makeSettings() -> SettingsStore {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("OmniWMCommandFeedbackTests-\(UUID().uuidString)", isDirectory: true)
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
