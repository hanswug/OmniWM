// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import AppKit
import Observation
import SwiftUI

struct CommandFeedbackMessage: Equatable {
    let symbol: String
    let text: String
}

@MainActor
final class CommandFeedbackHUD {
    static let shared = CommandFeedbackHUD()

    private static let size = CGSize(width: 200, height: 200)
    private static let fadeIn = 0.12
    private static let fadeOut = 0.25
    private static let hold = Duration.milliseconds(900)

    private let panel = CommandFeedbackPanel(size: CommandFeedbackHUD.size)
    private let model = CommandFeedbackModel()
    private var generation = 0
    private var hideTask: Task<Void, Never>?

    private init() {
        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: Self.size))
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.maskImage = Self.roundedMask(radius: 18)
        let content = NSHostingView(rootView: CommandFeedbackView(model: model, size: Self.size))
        content.frame = effect.bounds
        content.autoresizingMask = [.width, .height]
        effect.addSubview(content)
        panel.contentView = effect
    }

    func show(_ message: CommandFeedbackMessage) {
        generation += 1
        let current = generation
        model.message = message
        place()
        hideTask?.cancel()
        if panel.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0
                panel.animator().alphaValue = 1
            }
        } else {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = Self.fadeIn
                panel.animator().alphaValue = 1
            }
        }
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: Self.hold)
            guard !Task.isCancelled, let self, current == generation else { return }
            await NSAnimationContext.runAnimationGroup { context in
                context.duration = Self.fadeOut
                self.panel.animator().alphaValue = 0
            }
            guard current == generation else { return }
            panel.orderOut(nil)
        }
    }

    private func place() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
            ?? NSScreen.main
        else { return }
        let frame = screen.frame
        let origin = CGPoint(
            x: (frame.midX - Self.size.width / 2).rounded(),
            y: (frame.midY - Self.size.height / 2).rounded()
        )
        panel.setFrame(NSRect(origin: origin, size: Self.size), display: false)
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

private final class CommandFeedbackPanel: NSPanel {
    init(size: CGSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

@MainActor @Observable
private final class CommandFeedbackModel {
    var message = CommandFeedbackMessage(symbol: "checkmark.circle", text: "")
}

private struct CommandFeedbackView: View {
    let model: CommandFeedbackModel
    let size: CGSize

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: model.message.symbol)
                .font(.system(size: 64, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .frame(height: 76)
            Text(verbatim: model.message.text)
                .font(.system(size: 17, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 14)
        }
        .foregroundStyle(.primary)
        .frame(width: size.width, height: size.height)
        .accessibilityElement(children: .combine)
    }
}
