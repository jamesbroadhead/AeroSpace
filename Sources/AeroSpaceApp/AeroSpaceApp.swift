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
        }
    }

    var body: some Scene {
        menuBar(viewModel: viewModel)
        if #available(macOS 13, *) {
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
