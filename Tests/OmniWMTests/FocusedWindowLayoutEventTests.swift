// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import CoreGraphics
import Foundation
@testable import OmniWM
import OmniWMIPC
import XCTest

@MainActor
final class FocusedWindowLayoutEventTests: XCTestCase {
    private struct Fixture {
        let controller: WMController
        let workspaceId: WorkspaceDescriptor.ID
        let token: WindowToken
    }

    func testContainerFullPrimarySpanChangesAreReportedOnceEachWay() async throws {
        let fixture = try await makeFixture()
        let dispatcher = FocusNotificationDispatcher(controller: fixture.controller)
        dispatcher.notifyFocusChangesIfNeeded()
        XCTAssertFalse(dispatcher.focusedWindowLayoutStateChanged())

        XCTAssertTrue(fixture.controller.niriLayoutHandler.toggleContainerFullPrimarySpan())
        XCTAssertTrue(fixture.controller.isContainerFullPrimarySpan(fixture.token))
        XCTAssertTrue(dispatcher.focusedWindowLayoutStateChanged())
        XCTAssertFalse(dispatcher.focusedWindowLayoutStateChanged())

        XCTAssertTrue(fixture.controller.niriLayoutHandler.toggleContainerFullPrimarySpan())
        XCTAssertFalse(fixture.controller.isContainerFullPrimarySpan(fixture.token))
        XCTAssertTrue(dispatcher.focusedWindowLayoutStateChanged())
        XCTAssertFalse(dispatcher.focusedWindowLayoutStateChanged())
    }

    func testEnteringAndLeavingFullscreenAreBothReported() async throws {
        let fixture = try await makeFixture()
        let dispatcher = FocusNotificationDispatcher(controller: fixture.controller)
        dispatcher.notifyFocusChangesIfNeeded()

        fixture.controller.niriLayoutHandler.toggleFullscreen()
        XCTAssertTrue(fixture.controller.isLayoutFullscreen(fixture.token))
        XCTAssertTrue(dispatcher.focusedWindowLayoutStateChanged())

        fixture.controller.niriLayoutHandler.toggleFullscreen()
        XCTAssertFalse(fixture.controller.isLayoutFullscreen(fixture.token))
        XCTAssertTrue(dispatcher.focusedWindowLayoutStateChanged())
        XCTAssertFalse(dispatcher.focusedWindowLayoutStateChanged())
    }

    func testPendingFocusChangeLeavesTheLayoutChangeToTheFocusEvent() async throws {
        let fixture = try await makeFixture()
        let dispatcher = FocusNotificationDispatcher(controller: fixture.controller)

        XCTAssertFalse(dispatcher.focusedWindowLayoutStateChanged())
        XCTAssertEqual(dispatcher.notifyFocusChangesIfNeeded().focusChanged, true)
        XCTAssertFalse(dispatcher.focusedWindowLayoutStateChanged())
    }

    func testFocusSubscribersReceiveFullSpanAndFullscreenExitWithoutPolling() async throws {
        let fixture = try await makeFixture()
        let bridge = IPCApplicationBridge(
            controller: fixture.controller,
            appVersion: "0.0.0-test",
            sessionToken: "session",
            authorizationToken: "token"
        )
        addTeardownBlock { await bridge.shutdown() }
        fixture.controller.ipcApplicationBridge = bridge
        fixture.controller.focusNotificationDispatcher.notifyFocusChangesIfNeeded()
        let stream = await bridge.stream(for: .focus)

        XCTAssertEqual(
            fixture.controller.commandHandler.performCommand(.sizing(.toggleContainerFullPrimarySpan)),
            .executed
        )
        await WindowAdmissionTestSupport.drainLayoutRefreshes(fixture.controller)
        let fullSpan = try await nextFocusedWindow(in: stream)
        XCTAssertEqual(fullSpan?.isContainerFullPrimarySpan, true)
        XCTAssertEqual(fullSpan?.isFullscreen, false)

        XCTAssertEqual(fixture.controller.commandHandler.performCommand(.fullscreen(.managed)), .executed)
        await WindowAdmissionTestSupport.drainLayoutRefreshes(fixture.controller)
        let entered = try await nextFocusedWindow(in: stream)
        XCTAssertEqual(entered?.isFullscreen, true)

        XCTAssertEqual(fixture.controller.commandHandler.performCommand(.fullscreen(.managed)), .executed)
        await WindowAdmissionTestSupport.drainLayoutRefreshes(fixture.controller)
        let left = try await nextFocusedWindow(in: stream)
        XCTAssertEqual(left?.isFullscreen, false)
        XCTAssertEqual(left?.isContainerFullPrimarySpan, true)
    }

    private func nextFocusedWindow(in stream: AsyncStream<IPCEventEnvelope>) async throws -> IPCFocusedWindowSnapshot? {
        let received = expectation(description: "focus event received")
        var delivered: IPCEventEnvelope?
        let consumer = Task { @MainActor in
            var iterator = stream.makeAsyncIterator()
            delivered = await iterator.next()
            received.fulfill()
        }
        defer { consumer.cancel() }
        await fulfillment(of: [received], timeout: failureBound)
        let event = try XCTUnwrap(delivered)
        XCTAssertEqual(event.channel, .focus)
        guard case let .focusedWindow(result) = event.result.payload else {
            XCTFail("unexpected payload \(event.result.payload)")
            return nil
        }
        return result.window
    }

    private func makeFixture() async throws -> Fixture {
        let controller = WindowAdmissionTestSupport.controller(prefix: "FocusedWindowLayoutEventTests")
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
            name: "Focused Layout"
        )
        controller.workspaceManager.applyMonitorConfigurationChange([monitor])
        let workspaceId = try XCTUnwrap(controller.workspaceManager.workspaceId(for: "1", createIfMissing: true))
        XCTAssertTrue(controller.workspaceManager.setActiveWorkspace(workspaceId, on: monitor.id))
        var tokens: [WindowToken] = []
        for index in 0 ..< 2 {
            let token = WindowToken(pid: 7_701, windowId: 7_801 + index)
            tokens.append(token)
            _ = controller.workspaceManager.addWindow(
                WindowAdmissionTestSupport.axRef(for: token),
                pid: token.pid,
                windowId: token.windowId,
                to: workspaceId
            )
        }
        XCTAssertTrue(controller.workspaceManager.confirmManagedFocus(
            tokens[0],
            in: workspaceId,
            activateWorkspaceOnMonitor: false
        ))
        controller.layoutRefreshController.requestRelayout(reason: .monitorSettingsChanged)
        await WindowAdmissionTestSupport.drainLayoutRefreshes(controller)
        return Fixture(controller: controller, workspaceId: workspaceId, token: tokens[0])
    }
}
