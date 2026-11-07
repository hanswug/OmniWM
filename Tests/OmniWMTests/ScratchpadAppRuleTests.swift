// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import ApplicationServices
import Foundation
@testable import OmniWM
import XCTest

@MainActor
final class ScratchpadAppRuleTests: XCTestCase {
    private let monitorFrame = CGRect(x: 0, y: 0, width: 2400, height: 1200)
    private var notifications: [(title: String, body: String)] = []

    override func setUp() async throws {
        notifications = []
        ScratchpadNotifier.post = { [weak self] title, body in self?.notifications.append((title, body)) }
    }

    func testRuleWindowJoinsItsSlotParkedDuringStartup() throws {
        let fixture = try makeFixture()

        let token = fixture.addWindow(scratchpadSlot: 3)
        drainMainQueue()

        XCTAssertEqual(fixture.controller.workspaceManager.scratchpadIndex(for: token), 3)
        XCTAssertNil(fixture.controller.workspaceManager.revealedScratchpadIndex())
        XCTAssertNil(fixture.controller.workspaceManager.admissionHints(for: token)?.scratchpadSlot)
    }

    func testRuleWindowRevealsItsSlotWhenItArrivesLive() throws {
        let fixture = try makeFixture()
        fixture.controller.layoutRefreshController.layoutState.hasCompletedInitialRefresh = true

        let token = fixture.addWindow(scratchpadSlot: 3)
        drainMainQueue()

        XCTAssertEqual(fixture.controller.workspaceManager.scratchpadIndex(for: token), 3)
        XCTAssertEqual(fixture.controller.workspaceManager.revealedScratchpadIndex(), 3)
    }

    func testWindowReleasedByHandIsNotReassignedByTheRule() throws {
        let fixture = try makeFixture()
        let token = fixture.addWindow(scratchpadSlot: 3)
        drainMainQueue()
        XCTAssertEqual(fixture.controller.workspaceManager.scratchpadIndex(for: token), 3)

        fixture.controller.applyScratchpadRule(to: token)
        _ = fixture.controller.unassignScratchpadWindows([token], on: fixture.monitor.id)
        fixture.controller.applyScratchpadRule(to: token)
        drainMainQueue()

        XCTAssertNil(fixture.controller.workspaceManager.scratchpadIndex(for: token))
    }

    func testTogglingAnEmptyRuleSlotNotifiesWithTheAppName() throws {
        let fixture = try makeFixture()
        fixture.controller.settings.appRules = [AppRule(bundleId: "com.test.notes", assignToScratchpad: 4)]

        let result = fixture.controller.commandHandler.performCommand(.scratchpad(.toggle(4)))

        XCTAssertNotEqual(result, .executed)
        XCTAssertEqual(notifications.count, 1)
        XCTAssertEqual(notifications.first?.title, "Scratchpad 4")
        XCTAssertEqual(notifications.first?.body, "No com.test.notes window is open.")
    }

    func testTogglingAnEmptySlotWithoutARuleNotifiesThatItIsEmpty() throws {
        let fixture = try makeFixture()

        _ = fixture.controller.commandHandler.performCommand(.scratchpad(.toggle(7)))

        XCTAssertEqual(notifications.first?.title, "Scratchpad 7")
        XCTAssertEqual(notifications.first?.body, "It's empty.")
    }

    func testSlotModesRoundTripThroughTOML() throws {
        var export = SettingsExport.defaults()
        export.scratchpads.modes = ["4": .persistent, "7": .volatile, "11": .volatile]

        let decoded = try SettingsTOMLCodec.decode(SettingsTOMLCodec.encode(export))
        let settings = try makeFixture().controller.settings
        settings.applyExport(decoded)

        XCTAssertEqual(settings.scratchpadMode(for: 4), .persistent)
        XCTAssertEqual(settings.scratchpadMode(for: 7), .volatile)
        XCTAssertNil(settings.scratchpadMode(for: 11))
        XCTAssertNil(settings.scratchpadMode(for: 1))
    }

    func testQuitPlanFollowsTheSlotModes() throws {
        let fixture = try makeFixture()
        fixture.controller.settings.setScratchpadMode(.persistent, for: 1)
        fixture.controller.settings.setScratchpadMode(.volatile, for: 2)
        let persistent = fixture.addWindow(scratchpadSlot: 1)
        let volatile = fixture.addWindow(scratchpadSlot: 2)
        let unset = fixture.addWindow(scratchpadSlot: 3)
        drainMainQueue()
        XCTAssertEqual(fixture.controller.workspaceManager.scratchpadIndex(for: unset), 3)

        let plan = fixture.controller.scratchpadQuitPlan()

        XCTAssertEqual(plan.minimize.map(\.windowId), [persistent.windowId])
        XCTAssertEqual(plan.close.map(\.windowId), [volatile.windowId])
    }

    func testOnlyPersistentSlotsAreRemembered() throws {
        let fixture = try makeFixture()
        fixture.controller.settings.setScratchpadMode(.persistent, for: 1)
        fixture.controller.settings.setScratchpadMode(.volatile, for: 2)
        _ = fixture.addWindow(scratchpadSlot: 1)
        _ = fixture.addWindow(scratchpadSlot: 2)
        drainMainQueue()

        fixture.controller.rememberScratchpadMemberships()

        XCTAssertEqual(fixture.controller.settings.scratchpadMemberships.map(\.slot), [1])
    }

    func testTitleMatchNeedsAUniqueTitle() {
        let first = PersistedScratchpadMembership(
            bundleId: "com.apple.Safari",
            pid: 1,
            windowId: 10,
            title: "Docs",
            slot: 2
        )
        let second = PersistedScratchpadMembership(
            bundleId: "com.apple.Safari",
            pid: 1,
            windowId: 11,
            title: "Docs",
            slot: 3
        )
        let other = PersistedScratchpadMembership(
            bundleId: "com.apple.Safari",
            pid: 1,
            windowId: 12,
            title: "Mail",
            slot: 4
        )

        XCTAssertEqual(
            PersistedScratchpadMembership.titleMatch(in: [first, other], bundleId: "com.apple.Safari", title: "Docs"),
            first
        )
        XCTAssertNil(PersistedScratchpadMembership.titleMatch(
            in: [first, second],
            bundleId: "com.apple.Safari",
            title: "Docs"
        ))
        XCTAssertNil(PersistedScratchpadMembership.titleMatch(in: [first], bundleId: "com.apple.Notes", title: "Docs"))
    }

    private func drainMainQueue() {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 1)
    }

    private func makeFixture() throws -> Fixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("OmniWMScratchpadAppRuleTests-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let settings = SettingsStore(
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
        settings.borders.enabled = false
        settings.workspaceBar.enabled = false
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
        controller.motionPolicy.animationsEnabled = false
        controller.workspaceManager.applyMonitorConfigurationChange([monitor])
        controller.workspaceManager.applySettings()
        controller.niriLayoutHandler.enableNiriLayout()
        controller.syncMonitorsToNiriEngine()
        let workspaceId = try XCTUnwrap(controller.workspaceManager.workspaceId(named: "1"))
        XCTAssertTrue(controller.workspaceManager.setActiveWorkspace(workspaceId, on: monitor.id))
        return Fixture(controller: controller, monitor: monitor, workspaceId: workspaceId)
    }
}

@MainActor
private final class Fixture {
    let controller: WMController
    let monitor: Monitor
    let workspaceId: WorkspaceDescriptor.ID
    private var nextWindowId = 960

    init(controller: WMController, monitor: Monitor, workspaceId: WorkspaceDescriptor.ID) {
        self.controller = controller
        self.monitor = monitor
        self.workspaceId = workspaceId
    }

    func addWindow(scratchpadSlot: Int) -> WindowToken {
        nextWindowId += 1
        let token = controller.workspaceManager.addWindow(
            AXWindowRef(element: AXUIElementCreateApplication(pid_t(nextWindowId)), windowId: nextWindowId),
            pid: pid_t(nextWindowId),
            windowId: nextWindowId,
            to: workspaceId,
            mode: .floating,
            admissionHints: ManagedWindowAdmissionHints(scratchpadSlot: scratchpadSlot)
        )
        controller.workspaceManager.updateFloatingGeometry(
            frame: CGRect(x: 600, y: 300, width: 800, height: 600),
            for: token,
            referenceMonitor: monitor
        )
        return token
    }
}
