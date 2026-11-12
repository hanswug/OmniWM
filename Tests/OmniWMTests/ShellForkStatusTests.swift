// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import Foundation
@testable import OmniWM
import OmniWMScriptHost
import OmniWMShellCore
import XCTest

@MainActor
final class ShellForkStatusTests: XCTestCase {
    private let widgets = ["layout-vc", "window-state", "new-window-placement", "new-window-join", "padding"]

    private func status(
        layout: ActiveLayoutKind = .niri,
        fullscreen: Bool = false,
        fullSpan: Bool = false,
        focused: Bool = true,
        activePreset: Int? = 1
    ) -> ShellBarForkStatus {
        var status = ShellBarForkStatus()
        status.layout = layout
        status.visibleContainers = 2
        if focused {
            status.focusedWindow = .init(pid: 1, app: "Safari", fullscreen: fullscreen, fullSpan: fullSpan)
        }
        status.newWindowPlacement = NewWindowPlacement.first.rawValue
        status.newWindowJoin = NewWindowJoin.tabbed.rawValue
        status.paddingPresets = ["Fullscreen", "Wide Tall"].enumerated().map { index, name in
            .init(name: name, top: 540, bottom: 8, left: 8, right: 8, active: index == activePreset)
        }
        return status
    }

    private func bar(_ status: ShellBarForkStatus?) -> ShellBarData {
        var bar = ShellBarData()
        bar.status = status
        return bar
    }

    private func rendered(_ widget: String, _ status: ShellBarForkStatus?) throws -> ShellRenderedWidget {
        let rendered = try ShellRenderedWidget(widget)
        rendered.render(bar(status))
        return rendered
    }

    func testEveryStatusWidgetRendersItsBarAndPickerAndHidesWithoutStatus() throws {
        for widget in widgets {
            let full = try rendered(widget, status())
            XCTAssertGreaterThan(full.surface.size.width, 0, widget)
            XCTAssertFalse(full.renderPopout().isEmpty, widget)
            XCTAssertEqual(try rendered(widget, nil).surface.size.width, 0, widget)
        }
    }

    func testBarsShowTheCurrentValueAndClicksRunTheNextCommand() throws {
        XCTAssertTrue(try rendered("layout-vc", status()).strings().contains("VC 2"))
        XCTAssertTrue(try rendered("layout-vc", status()).commands().contains("set-visible-containers 3"))
        XCTAssertFalse(try rendered("layout-vc", status(layout: .dwindle)).strings().contains("VC 2"))
        XCTAssertTrue(try rendered("padding", status()).strings().contains("Wide Tall"))
        XCTAssertTrue(try rendered("padding", status(activePreset: nil)).strings().contains("Custom"))
        XCTAssertTrue(try rendered("padding", status()).commands().contains("cycle-padding-preset"))
        XCTAssertTrue(try rendered("new-window-placement", status()).commands().contains("cycle-new-window-placement"))
        XCTAssertTrue(try rendered("new-window-join", status()).commands().contains("cycle-new-window-join"))
        XCTAssertTrue(try rendered("window-state", status()).commands().contains("toggle-fullscreen"))
    }

    func testPickersOfferEverySetCommand() throws {
        let padding = try rendered("padding", status())
        padding.layoutPopout()
        XCTAssertTrue(padding.commands(OMNI_VIEW_POPOUT).contains("set-outer-gaps 8 8 540 8"))
        let join = try rendered("new-window-join", status())
        join.layoutPopout()
        for command in ["new-column", "tabbed", "stacked"] {
            XCTAssertTrue(join.commands(OMNI_VIEW_POPOUT).contains("new-window-join-\(command)"), command)
        }
        let placement = try rendered("new-window-placement", status())
        placement.layoutPopout()
        for command in ["right", "left", "first", "last"] {
            XCTAssertTrue(placement.commands(OMNI_VIEW_POPOUT).contains("new-window-placement-\(command)"), command)
        }
        let layout = try rendered("layout-vc", status())
        layout.layoutPopout()
        XCTAssertTrue(layout.commands(OMNI_VIEW_POPOUT).contains("set-visible-containers 5"))
        XCTAssertTrue(layout.commands(OMNI_VIEW_POPOUT).contains("toggle-workspace-layout"))
    }

    func testControllerStatusFollowsSettingsAndDerivesThePreset() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("OmniWMShellForkStatusTests-\(UUID().uuidString)", isDirectory: true)
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
        settings.gaps.paddingPresets = [
            SettingsExport.PaddingPreset(name: "Fullscreen", top: 8, bottom: 8, left: 8, right: 8),
            SettingsExport.PaddingPreset(name: "Wide Tall", top: 540, bottom: 8, left: 8, right: 8)
        ]
        let controller = WMController(settings: settings)
        controller.setOuterGaps(left: 8, right: 8, top: 540, bottom: 8)
        controller.setNewWindowPlacement(.last)
        controller.setNewWindowJoin(.stacked)
        controller.setVisibleContainerCount(4)

        let status = controller.shellForkStatus(on: Monitor.ID(displayId: 1))

        XCTAssertEqual(status.paddingPreset, "Wide Tall")
        XCTAssertEqual(status.newWindowPlacement, "last")
        XCTAssertEqual(status.newWindowJoin, "stacked")
        XCTAssertEqual(status.visibleContainers, 4)
        XCTAssertNil(status.focusedWindow)

        controller.setOuterGaps(left: 1, right: 2, top: 3, bottom: 4)
        XCTAssertNil(controller.shellForkStatus(on: Monitor.ID(displayId: 1)).paddingPreset)
    }
}

private extension ShellRenderedWidget {
    func commands(_ view: omni_view = OMNI_VIEW_BAR) -> [String] {
        output(view).withUnsafeBytes { buffer in
            guard buffer.count >= MemoryLayout<omni_wire_header>.stride else { return [] }
            let header = buffer.loadUnaligned(as: omni_wire_header.self)
            return (0 ..< Int(header.node_count)).compactMap { index -> String? in
                let node = buffer.loadUnaligned(
                    fromByteOffset: MemoryLayout<omni_wire_header>.stride + index * MemoryLayout<omni_wire_node>.stride,
                    as: omni_wire_node.self
                )
                return node.action == 0 ? nil : text.string(node.action)
            }
        }
    }
}
