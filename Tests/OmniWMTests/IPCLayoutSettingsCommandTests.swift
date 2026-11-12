// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import CoreGraphics
import Foundation
@testable import OmniWM
import OmniWMIPC
import XCTest

@MainActor
final class IPCLayoutSettingsCommandTests: XCTestCase {
    private struct Fixture {
        let controller: WMController
        let monitor: Monitor
    }

    func testSetVisibleContainersParsesOnlyCountsFromOneToFive() {
        XCTAssertEqual(
            IPCCommandRequest(commandWords: ["set-visible-containers", "3"]),
            .sizing(.setVisibleContainers(count: 3))
        )
        for invalid in ["0", "6", "-1", "two", "2.5"] {
            XCTAssertNil(IPCCommandRequest(commandWords: ["set-visible-containers", invalid]), invalid)
        }
        XCTAssertNil(IPCCommandRequest(commandWords: ["set-visible-containers"]))

        let outOfRange = Data(#"{"arguments":{"visibleContainerCount":6},"name":"set-visible-containers"}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(IPCCommandRequest.self, from: outOfRange))
    }

    func testSetOuterGapsParsesFourNonNegativeNumbersInLeftRightTopBottomOrder() {
        XCTAssertEqual(
            IPCCommandRequest(commandWords: ["set-outer-gaps", "40", "30.5", "0", "10"]),
            .sizing(.setOuterGaps(left: 40, right: 30.5, top: 0, bottom: 10))
        )
        XCTAssertNil(IPCCommandRequest(commandWords: ["set-outer-gaps", "40", "30", "0"]))
        XCTAssertNil(IPCCommandRequest(commandWords: ["set-outer-gaps", "40", "-1", "0", "10"]))
        XCTAssertNil(IPCCommandRequest(commandWords: ["set-outer-gaps", "40", "inf", "0", "10"]))

        let negative = Data(#"{"arguments":{"bottom":0,"left":-4,"right":0,"top":0},"name":"set-outer-gaps"}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(IPCCommandRequest.self, from: negative))
    }

    func testToggleBordersTakesNoArguments() {
        XCTAssertEqual(IPCCommandRequest(commandWords: ["toggle-borders"]), .presentation(.borders))
        XCTAssertNil(IPCCommandRequest(commandWords: ["toggle-borders", "on"]))
    }

    func testNewWindowJoinCommandsTakeNoArguments() throws {
        let commands: [(String, IPCPresentationCommand)] = [
            ("new-window-join-new-column", .newWindowJoinNewColumn),
            ("new-window-join-tabbed", .newWindowJoinTabbed),
            ("new-window-join-stacked", .newWindowJoinStacked),
            ("cycle-new-window-join", .cycleNewWindowJoin)
        ] + [
            ("cycle-padding-preset", .cyclePaddingPreset),
            ("cycle-new-window-placement", .cycleNewWindowPlacement),
            ("new-window-placement-right", .newWindowPlacementRight),
            ("new-window-placement-left", .newWindowPlacementLeft),
            ("new-window-placement-first", .newWindowPlacementFirst),
            ("new-window-placement-last", .newWindowPlacementLast)
        ]
        for (word, command) in commands {
            XCTAssertEqual(IPCCommandRequest(commandWords: [word]), .presentation(command))
            XCTAssertNil(IPCCommandRequest(commandWords: [word, "on"]))
            let descriptor = try XCTUnwrap(IPCAutomationManifest.commandDescriptor(for: .presentation(command)))
            XCTAssertEqual(descriptor.path, "command \(word)")
            XCTAssertEqual(descriptor.layoutCompatibility, .shared)
        }
    }

    func testManifestDescribesTheNewCommands() throws {
        let visible = try XCTUnwrap(IPCAutomationManifest.commandDescriptor(for: .sizing(.setVisibleContainers)))
        XCTAssertEqual(visible.path, "command set-visible-containers <1-5>")
        XCTAssertEqual(visible.layoutCompatibility, .niri)

        let gaps = try XCTUnwrap(IPCAutomationManifest.commandDescriptor(for: .sizing(.setOuterGaps)))
        XCTAssertEqual(gaps.path, "command set-outer-gaps <points> <points> <points> <points>")
        XCTAssertEqual(gaps.layoutCompatibility, .shared)

        let borders = try XCTUnwrap(IPCAutomationManifest.commandDescriptor(for: .presentation(.borders)))
        XCTAssertEqual(borders.path, "command toggle-borders")
    }

    func testNewHotkeyActionsAreAppendedAfterEveryExistingAction() throws {
        let ids = ActionCatalog.defaultHotkeyBindings().map(\.id)
        let added = ["toggleBorders"] + (1 ... 5).map { "setVisibleContainers.\($0)" } + [
            "newWindowJoin.newColumn", "newWindowJoin.tabbed", "newWindowJoin.stacked", "cycleNewWindowJoin",
            "cyclePaddingPreset", "cycleNewWindowPlacement", "newWindowPlacement.right", "newWindowPlacement.left",
            "newWindowPlacement.first",
            "newWindowPlacement.last"
        ]
        XCTAssertEqual(Array(ids.suffix(added.count)), added)

        let three = try XCTUnwrap(ActionCatalog.spec(for: "setVisibleContainers.3"))
        XCTAssertEqual(three.command, .sizing(.setVisibleContainers(3)))
        XCTAssertEqual(three.title, "Set Visible Containers 3")
        XCTAssertEqual(three.layoutCompatibility, .niri)
        XCTAssertEqual(three.ipcCommandName, .sizing(.setVisibleContainers))

        let borders = try XCTUnwrap(ActionCatalog.spec(for: "toggleBorders"))
        XCTAssertEqual(borders.command, .presentation(.borders))
        XCTAssertEqual(borders.title, "Toggle Borders")
        XCTAssertNil(ActionCatalog.spec(for: .sizing(.setOuterGaps(left: 1, right: 1, top: 1, bottom: 1))))
    }

    func testIPCSizingCommandsTranslateToHotkeyCommands() {
        XCTAssertEqual(
            HotkeyCommand(ipc: IPCSizingCommand.setVisibleContainers(count: 4)),
            .sizing(.setVisibleContainers(4))
        )
        XCTAssertEqual(
            HotkeyCommand(ipc: IPCSizingCommand.setOuterGaps(left: 1, right: 2, top: 3, bottom: 4)),
            .sizing(.setOuterGaps(left: 1, right: 2, top: 3, bottom: 4))
        )
    }

    func testSetOuterGapsSavesTheGapsAndShrinksTheWorkingArea() async throws {
        let fixture = try await makeFixture()
        let revision = fixture.controller.settings.layoutConfigurationRevision

        XCTAssertEqual(
            fixture.controller.commandHandler.performCommand(
                .sizing(.setOuterGaps(left: 40, right: 30, top: 20, bottom: 10))
            ),
            .executed
        )

        let outer = fixture.controller.settings.gaps.export().outer
        XCTAssertEqual([outer.left, outer.right, outer.top, outer.bottom], [40, 30, 20, 10])
        XCTAssertGreaterThan(fixture.controller.settings.layoutConfigurationRevision, revision)
        let after = fixture.controller.insetWorkingFrame(for: fixture.monitor)
        XCTAssertEqual(after.width, fixture.monitor.visibleFrame.width - 70)
        XCTAssertEqual(after.height, fixture.monitor.visibleFrame.height - 30)
    }

    func testToggleBordersFlipsAndSavesTheBorderSetting() async throws {
        let fixture = try await makeFixture()
        let initial = fixture.controller.settings.borders.enabled

        XCTAssertEqual(fixture.controller.commandHandler.performCommand(.presentation(.borders)), .executed)
        XCTAssertEqual(fixture.controller.settings.borders.enabled, !initial)

        XCTAssertEqual(fixture.controller.commandHandler.performCommand(.presentation(.borders)), .executed)
        XCTAssertEqual(fixture.controller.settings.borders.enabled, initial)
    }

    private func makeFixture() async throws -> Fixture {
        let controller = WindowAdmissionTestSupport.controller(prefix: "IPCLayoutSettingsCommandTests")
        controller.layoutRefreshController.displayLinkActivationForTests = { _ in true }
        controller.settings.animationsEnabled = false
        controller.enableNiriLayout()
        let frame = CGRect(x: 0, y: 0, width: 1600, height: 900)
        let monitor = Monitor(
            id: .init(displayId: 1),
            displayId: 1,
            frame: frame,
            visibleFrame: frame,
            hasNotch: false,
            name: "Layout Settings"
        )
        controller.workspaceManager.applyMonitorConfigurationChange([monitor])
        let workspaceId = try XCTUnwrap(controller.workspaceManager.workspaceId(for: "1", createIfMissing: true))
        XCTAssertTrue(controller.workspaceManager.setActiveWorkspace(workspaceId, on: monitor.id))
        let token = WindowToken(pid: 7_501, windowId: 7_601)
        _ = controller.workspaceManager.addWindow(
            WindowAdmissionTestSupport.axRef(for: token),
            pid: token.pid,
            windowId: token.windowId,
            to: workspaceId
        )
        controller.layoutRefreshController.requestRelayout(reason: .monitorSettingsChanged)
        await WindowAdmissionTestSupport.drainLayoutRefreshes(controller)
        return Fixture(controller: controller, monitor: monitor)
    }
}
