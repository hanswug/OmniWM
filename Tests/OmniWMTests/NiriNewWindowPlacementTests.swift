// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import CoreGraphics
@testable import OmniWM
import XCTest

@MainActor
final class NiriNewWindowPlacementTests: XCTestCase {
    private let a = WindowToken(pid: 880, windowId: 1)
    private let b = WindowToken(pid: 880, windowId: 2)
    private let c = WindowToken(pid: 880, windowId: 3)
    private let new = WindowToken(pid: 880, windowId: 9)

    func testRightIsTheDefaultAndOpensNextToTheFocusedColumn() {
        let (engine, workspaceId) = makeEngine()
        XCTAssertEqual(engine.newWindowPlacement, .right)
        _ = engine.addWindow(token: new, to: workspaceId, afterSelection: nil, focusedToken: a)
        XCTAssertEqual(order(engine, workspaceId), [[a], [new], [b], [c]])
    }

    func testLeftOpensBeforeTheFocusedColumn() {
        let (engine, workspaceId) = makeEngine(placement: .left)
        _ = engine.addWindow(token: new, to: workspaceId, afterSelection: nil, focusedToken: b)
        XCTAssertEqual(order(engine, workspaceId), [[a], [new], [b], [c]])
    }

    func testFirstAndLastIgnoreTheFocusedColumn() {
        let (first, firstWorkspace) = makeEngine(placement: .first)
        _ = first.addWindow(token: new, to: firstWorkspace, afterSelection: nil, focusedToken: b)
        XCTAssertEqual(order(first, firstWorkspace), [[new], [a], [b], [c]])

        let (last, lastWorkspace) = makeEngine(placement: .last)
        _ = last.addWindow(token: new, to: lastWorkspace, afterSelection: nil, focusedToken: a)
        XCTAssertEqual(order(last, lastWorkspace), [[a], [b], [c], [new]])
    }

    func testATabbedNeighbourOnThePlacementSideTakesTheWindowAsATab() {
        let (right, rightWorkspace) = makeEngine(placement: .right)
        right.columns(in: rightWorkspace)[1].displayMode = .tabbed
        _ = right.addWindow(token: new, to: rightWorkspace, afterSelection: nil, focusedToken: a)
        XCTAssertEqual(order(right, rightWorkspace), [[a], [b, new], [c]])

        let (left, leftWorkspace) = makeEngine(placement: .left)
        left.columns(in: leftWorkspace)[0].displayMode = .tabbed
        _ = left.addWindow(token: new, to: leftWorkspace, afterSelection: nil, focusedToken: b)
        XCTAssertEqual(order(left, leftWorkspace), [[a, new], [b], [c]])

        let (last, lastWorkspace) = makeEngine(placement: .last)
        last.columns(in: lastWorkspace)[2].displayMode = .tabbed
        _ = last.addWindow(token: new, to: lastWorkspace, afterSelection: nil, focusedToken: a)
        XCTAssertEqual(order(last, lastWorkspace), [[a], [b], [c, new]])
    }

    func testTabbedNeighboursAreIgnoredUnlessEnabled() {
        let (engine, workspaceId) = makeEngine(placement: .right, joinsTabbedColumn: false)
        engine.columns(in: workspaceId)[1].displayMode = .tabbed
        _ = engine.addWindow(token: new, to: workspaceId, afterSelection: nil, focusedToken: a)
        XCTAssertEqual(order(engine, workspaceId), [[a], [new], [b], [c]])
        XCTAssertFalse(NiriLayoutEngine().newWindowJoinsTabbedColumn)
    }

    func testATabbedFocusedColumnDoesNotTakeTheWindow() {
        let (engine, workspaceId) = makeEngine(placement: .right)
        engine.columns(in: workspaceId)[0].displayMode = .tabbed
        _ = engine.addWindow(token: new, to: workspaceId, afterSelection: nil, focusedToken: a)
        XCTAssertEqual(order(engine, workspaceId), [[a], [new], [b], [c]])
    }

    func testAWindowWithItsOwnSizeAlwaysGetsItsOwnColumn() {
        let (engine, workspaceId) = makeEngine(placement: .right)
        engine.columns(in: workspaceId)[1].displayMode = .tabbed
        _ = engine.addWindow(
            token: new,
            to: workspaceId,
            afterSelection: nil,
            focusedToken: a,
            containerSizingState: engine.initialContainerSizingState(for: 0.5)
        )
        XCTAssertEqual(order(engine, workspaceId), [[a], [new], [b], [c]])
    }

    func testFirstWindowOnAnEmptyWorkspaceIsUnaffected() {
        let engine = NiriLayoutEngine()
        engine.newWindowPlacement = .first
        let workspaceId = WorkspaceDescriptor.ID()
        _ = engine.addWindow(token: new, to: workspaceId, afterSelection: nil)
        XCTAssertEqual(order(engine, workspaceId), [[new]])
    }

    func testTheSettingReachesTheEngine() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("OmniWMNiriNewWindowPlacementTests-\(UUID().uuidString)", isDirectory: true)
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
        settings.niri.newWindowPlacement = .last
        settings.niri.newWindowJoinsTabbedColumn = true
        let controller = WMController(settings: settings)
        controller.enableNiriLayout()
        XCTAssertEqual(controller.niriEngine?.newWindowPlacement, .last)
        XCTAssertEqual(controller.niriEngine?.newWindowJoinsTabbedColumn, true)

        let export = settings.toExport()
        XCTAssertEqual(export.niri.newWindowPlacement, .last)
        settings.niri.newWindowPlacement = .right
        XCTAssertNil(settings.toExport().niri.newWindowPlacement)
    }

    private func makeEngine(
        placement: NewWindowPlacement? = nil,
        joinsTabbedColumn: Bool = true
    ) -> (NiriLayoutEngine, WorkspaceDescriptor.ID) {
        let engine = NiriLayoutEngine()
        let workspaceId = WorkspaceDescriptor.ID()
        _ = engine.addWindow(token: a, to: workspaceId, afterSelection: nil)
        _ = engine.addWindow(token: b, to: workspaceId, afterSelection: nil, focusedToken: a)
        _ = engine.addWindow(token: c, to: workspaceId, afterSelection: nil, focusedToken: b)
        if let placement {
            engine.newWindowPlacement = placement
        }
        engine.newWindowJoinsTabbedColumn = joinsTabbedColumn
        return (engine, workspaceId)
    }

    private func order(_ engine: NiriLayoutEngine, _ workspaceId: WorkspaceDescriptor.ID) -> [[WindowToken]] {
        engine.columns(in: workspaceId).map { $0.windowNodes.map(\.token) }
    }
}
