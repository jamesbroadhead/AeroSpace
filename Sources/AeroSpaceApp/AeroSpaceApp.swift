import AppBundle
import SwiftUI

// This file is shared between SPM and xcode project

@main
struct AeroSpaceApp: App {
    @StateObject var viewModel = TrayMenuModel.shared
    @StateObject var messageModel = MessageModel.shared

    init() {
        initAppBundle()
        if #available(macOS 13, *) {} else {
            MessageWindowPresenter.shared.startObserving()
            LegacyMenuBar.shared.start()
        }
    }

    var body: some Scene {
        // SwiftUI.App requires at least one Scene. On macOS 12 the UI is created imperatively
        // via NSStatusItem (LegacyMenuBar) and NSPanel (MessageWindowPresenter), so an empty
        // Settings scene is used as a placeholder there, while MenuBarExtra shuts it out on 13+.
        Settings { EmptyView() }
        if #available(macOS 13, *) {
            menuBar(viewModel: viewModel)
            MessageWindowScene(messageModel: messageModel)
        }
    }
}

@available(macOS 13.0, *)
@MainActor
private struct MessageWindowScene: Scene {
    @Environment(\.openWindow) var openWindow: OpenWindowAction
    @ObservedObject var messageModel: MessageModel

    var body: some Scene {
        getMessageWindow(messageModel: messageModel)
            .onChange(of: messageModel.message) { message in
                if message != nil {
                    openWindow(id: messageWindowId)
                }
            }
    }
}
