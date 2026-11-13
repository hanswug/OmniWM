// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import AppKit

@MainActor
enum CommandFeedback {
    static var present: (CommandFeedbackMessage) -> Void = { CommandFeedbackHUD.shared.show($0) }
    static var lastFocusedWindowLayout: FocusedWindowLayoutState?

    static func visibleContainers(_ count: Int) -> CommandFeedbackMessage {
        CommandFeedbackMessage(symbol: "inset.filled.leftthird.middlethird.rightthird.rectangle", text: "VC \(count)")
    }

    static func paddingPreset(_ name: String) -> CommandFeedbackMessage {
        CommandFeedbackMessage(symbol: "square.arrowtriangle.4.outward", text: name)
    }

    static func borders(_ enabled: Bool) -> CommandFeedbackMessage {
        CommandFeedbackMessage(
            symbol: enabled ? "square" : "square.dashed",
            text: enabled ? "Borders on" : "Borders off"
        )
    }

    static func newWindowJoin(_ join: NewWindowJoin) -> CommandFeedbackMessage {
        switch join {
        case .newColumn: CommandFeedbackMessage(symbol: "rectangle.split.2x1", text: "New windows: New Column")
        case .tabbed: CommandFeedbackMessage(symbol: "rectangle.topthird.inset.filled", text: "New windows: Tabbed")
        case .stacked: CommandFeedbackMessage(symbol: "rectangle.split.1x2", text: "New windows: Stacked")
        }
    }

    static func newWindowPlacement(_ placement: NewWindowPlacement) -> CommandFeedbackMessage {
        switch placement {
        case .right: CommandFeedbackMessage(
                symbol: "inset.filled.righthalf.arrow.right.rectangle",
                text: "New windows: Right"
            )
        case .left: CommandFeedbackMessage(
                symbol: "inset.filled.lefthalf.arrow.left.rectangle",
                text: "New windows: Left"
            )
        case .first: CommandFeedbackMessage(
                symbol: "arrow.left.to.line", text: "New windows: First"
            )
        case .last: CommandFeedbackMessage(
                symbol: "arrow.right.to.line", text: "New windows: Last"
            )
        }
    }

    static func sizeLimit(app: String, minimum: Bool, width: CGFloat) -> CommandFeedbackMessage {
        CommandFeedbackMessage(
            symbol: minimum ? "arrow.right.and.line.vertical.and.arrow.left" :
                "arrow.left.and.line.vertical.and.arrow.right",
            text: "\(app): \(minimum ? "minimum" : "maximum") \(Int(width.rounded()))"
        )
    }

    static func layoutChange(
        from previous: FocusedWindowLayoutState?,
        to current: FocusedWindowLayoutState
    ) -> CommandFeedbackMessage? {
        guard let previous, previous.token != nil, previous.token == current.token else { return nil }
        if previous.isFullscreen != current.isFullscreen {
            return current.isFullscreen
                ? CommandFeedbackMessage(symbol: "arrow.up.left.and.arrow.down.right", text: "Fullscreen on")
                : CommandFeedbackMessage(symbol: "arrow.down.right.and.arrow.up.left", text: "Fullscreen off")
        }
        if previous.isContainerFullPrimarySpan != current.isContainerFullPrimarySpan {
            return current.isContainerFullPrimarySpan
                ? CommandFeedbackMessage(symbol: "arrow.left.and.right", text: "Full container on")
                : CommandFeedbackMessage(
                    symbol: "arrow.right.and.line.vertical.and.arrow.left",
                    text: "Full container off"
                )
        }
        return nil
    }
}

extension WMController {
    func showCommandFeedback(_ message: CommandFeedbackMessage) {
        guard settings.commandFeedback else { return }
        CommandFeedback.present(message)
    }

    func showSizeLimitFeedback(for token: WindowToken, minimum: Bool, width: CGFloat) {
        let app = NSRunningApplication(processIdentifier: token.pid)?.localizedName ?? "Window"
        showCommandFeedback(CommandFeedback.sizeLimit(app: app, minimum: minimum, width: width))
    }

    func noteFocusedWindowLayoutForFeedback() {
        let current = focusedWindowLayoutState()
        let previous = CommandFeedback.lastFocusedWindowLayout
        let message = CommandFeedback.layoutChange(from: previous, to: current)
        CommandFeedback.lastFocusedWindowLayout = current
        if previous != current {
            requestWorkspaceBarRefresh()
        }
        if let message {
            showCommandFeedback(message)
        }
    }
}
