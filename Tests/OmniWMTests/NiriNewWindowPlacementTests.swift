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

    func testNewColumnIsTheDefaultAndIgnoresTabbedNeighbours() {
        XCTAssertEqual(NiriLayoutEngine().newWindowJoin, .newColumn)
        let (engine, workspaceId) = makeEngine(placement: .right)
        engine.columns(in: workspaceId)[1].displayMode = .tabbed
        _ = engine.addWindow(token: new, to: workspaceId, afterSelection: nil, focusedToken: a)
        XCTAssertEqual(order(engine, workspaceId), [[a], [new], [b], [c]])
    }

    func testTabbedJoinsTheColumnOnThePlacementSideAndMakesItTabbed() {
        let (right, rightWorkspace) = makeEngine(placement: .right, join: .tabbed)
        _ = right.addWindow(token: new, to: rightWorkspace, afterSelection: nil, focusedToken: a)
        XCTAssertEqual(order(right, rightWorkspace), [[a], [b, new], [c]])
        XCTAssertTrue(right.columns(in: rightWorkspace)[1].isTabbed)

        let (left, leftWorkspace) = makeEngine(placement: .left, join: .tabbed)
        left.columns(in: leftWorkspace)[0].displayMode = .tabbed
        _ = left.addWindow(token: new, to: leftWorkspace, afterSelection: nil, focusedToken: b)
        XCTAssertEqual(order(left, leftWorkspace), [[a, new], [b], [c]])
    }

    func testStackedJoinsTheColumnWithoutChangingItsMode() {
        let (engine, workspaceId) = makeEngine(placement: .right, join: .stacked)
        _ = engine.addWindow(token: new, to: workspaceId, afterSelection: nil, focusedToken: a)
        XCTAssertEqual(order(engine, workspaceId), [[a], [b, new], [c]])
        XCTAssertFalse(engine.columns(in: workspaceId)[1].isTabbed)

        let (tabbed, tabbedWorkspace) = makeEngine(placement: .right, join: .stacked)
        tabbed.columns(in: tabbedWorkspace)[1].displayMode = .tabbed
        _ = tabbed.addWindow(token: new, to: tabbedWorkspace, afterSelection: nil, focusedToken: a)
        XCTAssertEqual(order(tabbed, tabbedWorkspace), [[a], [b, new], [c]])
        XCTAssertTrue(tabbed.columns(in: tabbedWorkspace)[1].isTabbed)
    }

    func testWithoutAColumnOnThatSideTheFocusedColumnTakesTheWindow() {
        for join in [NewWindowJoin.tabbed, .stacked] {
            let (right, rightWorkspace) = makeEngine(placement: .right, join: join)
            _ = right.addWindow(token: new, to: rightWorkspace, afterSelection: nil, focusedToken: c)
            XCTAssertEqual(order(right, rightWorkspace), [[a], [b], [c, new]])

            let (left, leftWorkspace) = makeEngine(placement: .left, join: join)
            _ = left.addWindow(token: new, to: leftWorkspace, afterSelection: nil, focusedToken: a)
            XCTAssertEqual(order(left, leftWorkspace), [[a, new], [b], [c]])
        }
    }

    func testFirstAndLastJoinThoseColumns() {
        let (first, firstWorkspace) = makeEngine(placement: .first, join: .stacked)
        _ = first.addWindow(token: new, to: firstWorkspace, afterSelection: nil, focusedToken: b)
        XCTAssertEqual(order(first, firstWorkspace), [[a, new], [b], [c]])

        let (last, lastWorkspace) = makeEngine(placement: .last, join: .tabbed)
        _ = last.addWindow(token: new, to: lastWorkspace, afterSelection: nil, focusedToken: a)
        XCTAssertEqual(order(last, lastWorkspace), [[a], [b], [c, new]])
        XCTAssertTrue(last.columns(in: lastWorkspace)[2].isTabbed)
    }

    func testEveryNewWindowJoinsWhileTheModeIsOn() {
        let (engine, workspaceId) = makeEngine(placement: .right, join: .stacked)
        let another = WindowToken(pid: 880, windowId: 10)
        _ = engine.addWindow(token: new, to: workspaceId, afterSelection: nil, focusedToken: a)
        _ = engine.addWindow(token: another, to: workspaceId, afterSelection: nil, focusedToken: a)
        XCTAssertEqual(engine.columns(in: workspaceId).count, 3)
        XCTAssertEqual(Set(order(engine, workspaceId)[1]), [b, new, another])
    }

    func testAWindowWithItsOwnSizeAlwaysGetsItsOwnColumn() {
        for join in [NewWindowJoin.tabbed, .stacked] {
            let (engine, workspaceId) = makeEngine(placement: .right, join: join)
            _ = engine.addWindow(
                token: new,
                to: workspaceId,
                afterSelection: nil,
                focusedToken: a,
                containerSizingState: engine.initialContainerSizingState(for: 0.5)
            )
            XCTAssertEqual(order(engine, workspaceId), [[a], [new], [b], [c]])
        }
    }

    func testFirstWindowOnAnEmptyWorkspaceIsUnaffected() {
        let engine = NiriLayoutEngine()
        engine.newWindowPlacement = .first
        engine.newWindowJoin = .tabbed
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
        settings.niri.newWindowJoin = .stacked
        let controller = WMController(settings: settings)
        controller.enableNiriLayout()
        XCTAssertEqual(controller.niriEngine?.newWindowPlacement, .last)
        XCTAssertEqual(controller.niriEngine?.newWindowJoin, .stacked)

        let export = settings.toExport()
        XCTAssertEqual(export.niri.newWindowPlacement, .last)
        XCTAssertEqual(export.niri.newWindowJoin, .stacked)
        XCTAssertNil(export.niri.newWindowJoinsTabbedColumn)
        settings.niri.newWindowPlacement = .right
        settings.niri.newWindowJoin = .newColumn
        XCTAssertNil(settings.toExport().niri.newWindowPlacement)
        XCTAssertNil(settings.toExport().niri.newWindowJoin)

        controller.cycleNewWindowJoin()
        XCTAssertEqual(settings.niri.newWindowJoin, .tabbed)
        XCTAssertEqual(controller.niriEngine?.newWindowJoin, .tabbed)
        controller.cycleNewWindowJoin()
        controller.cycleNewWindowJoin()
        XCTAssertEqual(settings.niri.newWindowJoin, .newColumn)
    }

    func testTheOldTabbedColumnSettingReadsAsTabbed() {
        var legacy = NiriSettings().export()
        legacy.newWindowJoin = nil
        legacy.newWindowJoinsTabbedColumn = true
        let settings = NiriSettings()
        settings.apply(legacy, baseline: NiriSettings().export())
        XCTAssertEqual(settings.newWindowJoin, .tabbed)

        legacy.newWindowJoinsTabbedColumn = false
        settings.apply(legacy, baseline: NiriSettings().export())
        XCTAssertEqual(settings.newWindowJoin, .newColumn)
    }

    private func makeEngine(
        placement: NewWindowPlacement? = nil,
        join: NewWindowJoin = .newColumn
    ) -> (NiriLayoutEngine, WorkspaceDescriptor.ID) {
        let engine = NiriLayoutEngine()
        let workspaceId = WorkspaceDescriptor.ID()
        _ = engine.addWindow(token: a, to: workspaceId, afterSelection: nil)
        _ = engine.addWindow(token: b, to: workspaceId, afterSelection: nil, focusedToken: a)
        _ = engine.addWindow(token: c, to: workspaceId, afterSelection: nil, focusedToken: b)
        if let placement {
            engine.newWindowPlacement = placement
        }
        engine.newWindowJoin = join
        return (engine, workspaceId)
    }

    private func order(_ engine: NiriLayoutEngine, _ workspaceId: WorkspaceDescriptor.ID) -> [[WindowToken]] {
        engine.columns(in: workspaceId).map { $0.windowNodes.map(\.token) }
    }
}
