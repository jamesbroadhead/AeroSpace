import AppKit
import Combine
import Common
import SwiftUI

// macOS 12 fallback for the message window.
// SwiftUI.Window scene (MessageView.swift) is only available since macOS 13,
// so on older systems we host MessageView in an NSPanel and observe MessageModel directly.
@MainActor
public final class MessageWindowPresenter {
    public static let shared = MessageWindowPresenter()

    private let model = MessageModel.shared
    private var panel: NSPanel?
    private var cancellable: AnyCancellable?

    private init() {}

    public func startObserving() {
        guard cancellable == nil else { return }
        cancellable = model.$message
            .sink { [weak self] message in
                if message != nil {
                    self?.show()
                } else {
                    self?.hide()
                }
            }
    }

    private func show() {
        FileLog.log("MessageWindowPresenter.show(title=\(model.message?.title ?? "nil"))")
        guard panel == nil else {
            panel?.makeKeyAndOrderFront(nil)
            return
        }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false,
        )
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.contentMinSize = NSSize(width: 480, height: 200)
        panel.title = model.message?.title ?? aeroSpaceAppName
        panel.contentView = NSHostingView(rootView: MessageView(model: model))
        self.panel = panel
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.accessory)
    }

    private func hide() {
        FileLog.log("MessageWindowPresenter.hide")
        panel?.orderOut(nil)
    }
}