// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import ApplicationServices
import Foundation
@testable import OmniWM
import XCTest

@MainActor
final class NiriObservedMinimumRetestTests: XCTestCase {
    private let monitorFrame = CGRect(x: 0, y: 0, width: 2400, height: 1200)

    func testExplicitResizeRetestsStaleObservedMinimum() throws {
        let fixture = try makeFixture()
        try learnMinimumWidth(1299, fixture: fixture)
        XCTAssertGreaterThanOrEqual(try layoutFrame(fixture).width, 1299)

        XCTAssertTrue(fixture.controller.niriLayoutHandler.setContainerPrimarySpan(
            .setFixed(800),
            target: .window(fixture.handle)
        ))

        XCTAssertEqual(try layoutFrame(fixture).width, 800, accuracy: 0.5)
        XCTAssertNil(fixture.controller.workspaceManager.observedSizeEvidence(for: fixture.token))
    }

    func testRepeatedShrinkStepsPassAStaleObservedMinimum() throws {
        let fixture = try makeFixture()
        try learnMinimumWidth(1299, fixture: fixture)
        let startWidth = try layoutFrame(fixture).width

        for _ in 0 ..< 3 {
            fixture.controller.niriLayoutHandler.setWindowPrimarySpan(
                .adjustProportion(-10),
                target: .window(fixture.handle)
            )
        }

        XCTAssertLessThan(try layoutFrame(fixture).width, min(startWidth, 1299) - 1)
    }

    func testGrowingAfterRefusedShrinkStepsStartsFromTheRefusedWidth() throws {
        for resizesWindow in [false, true] {
            let fixture = try makeFixture()
            try learnMinimumWidth(1299, fixture: fixture)

            for _ in 0 ..< 3 {
                adjust(-10, resizesWindow: resizesWindow, fixture: fixture)
                try learnMinimumWidth(1299, fixture: fixture)
            }
            XCTAssertEqual(try layoutFrame(fixture).width, 1299)

            adjust(10, resizesWindow: resizesWindow, fixture: fixture)

            XCTAssertGreaterThan(try layoutFrame(fixture).width, 1299)
        }
    }

    func testExplicitResizeKeepsTheAppsDeclaredMinimum() throws {
        let fixture = try makeFixture()
        fixture.controller.workspaceManager.setCachedConstraints(
            WindowSizeConstraints(minSize: CGSize(width: 900, height: 1), maxSize: .zero, isFixed: false),
            for: fixture.token
        )
        try learnMinimumWidth(1299, fixture: fixture)

        XCTAssertTrue(fixture.controller.niriLayoutHandler.setContainerPrimarySpan(
            .setFixed(800),
            target: .window(fixture.handle)
        ))

        XCTAssertEqual(try layoutFrame(fixture).width, 900, accuracy: 0.5)
    }

    func testObservedHeightMinimumSurvivesAWidthResize() throws {
        let fixture = try makeFixture()
        var evidence = ObservedSizeEvidence()
        evidence.minSize = CGSize(width: 1299, height: 700)
        _ = fixture.controller.workspaceManager.setObservedSizeEvidence(evidence, for: fixture.token)
        _ = try layoutFrame(fixture)

        XCTAssertTrue(fixture.controller.niriLayoutHandler.setContainerPrimarySpan(
            .setFixed(800),
            target: .window(fixture.handle)
        ))

        let remaining = try XCTUnwrap(fixture.controller.workspaceManager.observedSizeEvidence(for: fixture.token))
        XCTAssertLessThanOrEqual(remaining.minSize.width, 1)
        XCTAssertEqual(remaining.minSize.height, 700)
    }

    private struct Fixture {
        let controller: WMController
        let workspaceId: WorkspaceDescriptor.ID
        let token: WindowToken
        let handle: WindowHandle
    }

    private func adjust(_ percent: Double, resizesWindow: Bool, fixture: Fixture) {
        let handler = fixture.controller.niriLayoutHandler
        if resizesWindow {
            handler.setWindowPrimarySpan(.adjustProportion(percent), target: .window(fixture.handle))
        } else {
            handler.setContainerPrimarySpan(.adjustProportion(percent), target: .window(fixture.handle))
        }
    }

    private func learnMinimumWidth(_ width: CGFloat, fixture: Fixture) throws {
        var evidence = ObservedSizeEvidence()
        evidence.minSize = CGSize(width: width, height: 1)
        XCTAssertTrue(fixture.controller.workspaceManager.setObservedSizeEvidence(evidence, for: fixture.token))
        _ = try layoutFrame(fixture)
    }

    private func makeFixture() throws -> Fixture {
        let settings = makeSettingsStore()
        settings.borders.enabled = false
        settings.workspaceBar.enabled = false
        settings.gaps.size = 10
        settings.gaps.outerGapLeft = 0
        settings.gaps.outerGapRight = 0
        settings.gaps.outerGapTop = 0
        settings.gaps.outerGapBottom = 0
        let monitor = Monitor(
            id: .init(displayId: 1),
            displayId: 1,
            frame: monitorFrame,
            visibleFrame: monitorFrame,
            hasNotch: false,
            name: "Main"
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
                AXWindowRef(element: AXUIElementCreateApplication(pid_t(850 + index)), windowId: 850 + index),
                pid: pid_t(850 + index),
                windowId: 850 + index,
                to: workspaceId
            )
        }
        let fixture = try Fixture(
            controller: controller,
            workspaceId: workspaceId,
            token: tokens[0],
            handle: XCTUnwrap(controller.workspaceManager.handle(for: tokens[0]))
        )
        _ = try layoutFrame(fixture)
        return fixture
    }

    private func layoutFrame(_ fixture: Fixture) throws -> CGRect {
        let plans = fixture.controller.workspaceManager.withBatchedLayoutBuild {
            fixture.controller.niriLayoutHandler.layoutWithNiriEngine(activeWorkspaces: [fixture.workspaceId])
        }
        let plan = try XCTUnwrap(plans.first { $0.workspaceId == fixture.workspaceId })
        if let frame = plan.diff.frameChanges.first(where: { $0.token == fixture.token })?.frame {
            return frame
        }
        let engine = try XCTUnwrap(fixture.controller.niriEngine)
        return try XCTUnwrap(engine.findNode(for: fixture.token, in: fixture.workspaceId)?.renderedFrame)
    }

    private func makeSettingsStore() -> SettingsStore {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("OmniWMNiriObservedMinimumRetestTests-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
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
