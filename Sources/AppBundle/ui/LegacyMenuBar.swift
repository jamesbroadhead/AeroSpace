import AppKit
import Combine
import Common
import SwiftUI

// macOS 12 fallback for the tray menu.
// MenuBarExtra scene (MenuBar.swift) is only available since macOS 13, so on older systems
// we create an NSStatusItem + NSMenu and mirror the MenuBarExtra content of MenuBar.swift.
@MainActor
public final class LegacyMenuBar {
    public static let shared = LegacyMenuBar()

    private let viewModel = TrayMenuModel.shared
    private var statusItem: NSStatusItem?
    private var cancellable: AnyCancellable?
    private var actionTargets: [LegacyMenuActionTarget] = []

    private init() {}

    public func start() {
        guard statusItem == nil else { return }
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem
        updateStatusItem()
        cancellable = viewModel.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.updateStatusItem() }
        }
    }

    private func updateStatusItem() {
        guard let statusItem else { return }
        statusItem.button?.image = nil
        switch (viewModel.axPermissionStatus, viewModel.isEnabled) {
            case (.granted, true):
                statusItem.button?.title = viewModel.trayText
            case (.granted, false):
                statusItem.button?.title = ""
                statusItem.button?.image = NSImage(systemSymbolName: "pause.circle.fill", accessibilityDescription: "AeroSpace is disabled")?.resized(maxDimension: 16)
            case (_, _):
                statusItem.button?.title = ""
                statusItem.button?.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "AeroSpace requires accessibility permission")?.resized(maxDimension: 16)
        }
        statusItem.menu = buildMenu()
    }

    // Mirrors the menu content of MenuBar.swift:7-88
    private func buildMenu() -> NSMenu {
        actionTargets.removeAll()
        let menu = NSMenu()
        let shortIdentification = "\(aeroSpaceAppName) v\(aeroSpaceAppVersion) \(gitShortHash)"
        let identification      = "\(aeroSpaceAppName) v\(aeroSpaceAppVersion) \(gitHash)"

        menu.addItem(disabledItem(shortIdentification))
        addActionItem(menu, title: "Copy to clipboard", keyEquivalent: "c") { identification.copyToClipboard() }
        menu.addItem(.separator())

        if viewModel.axPermissionStatus == .granted {
            if let token: RunSessionGuard = .isServerEnabled, viewModel.lastReloadConfigContainedWarnings {
                addActionItem(menu, title: "Config contains warnings...", systemImage: "exclamationmark.triangle.fill") {
                    Task.startUnstructured {
                        try await runLightSession(.menuBarButton, token) {
                            let args: ReloadConfigCmdArgs = ReloadConfigCmdArgs(rawArgs: []).copy(\.warningsAsErrors, true)
                            _ = await reloadConfig_nonCancellable(args: args)
                        }
                    }
                }
                menu.addItem(.separator())
            }
            if let token: RunSessionGuard = .isServerEnabled {
                menu.addItem(disabledItem("Workspaces:"))
                for workspace in viewModel.workspaces {
                    let item = NSMenuItem(title: workspace.name + workspace.suffix, action: nil, keyEquivalent: "")
                    item.attributedTitle = NSAttributedString(
                        string: workspace.name + workspace.suffix,
                        attributes: [.font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)]
                    )
                    item.state = workspace.isFocused ? .on : .off
                    let target = LegacyMenuActionTarget {
                        Task.startUnstructured {
                            try await runLightSession(.menuBarButton, token) { _ = Workspace.get(byName: workspace.name).focusWorkspace() }
                        }
                    }
                    actionTargets.append(target)
                    item.target = target
                    item.action = #selector(LegacyMenuActionTarget.onAction)
                    menu.addItem(item)
                }
                menu.addItem(.separator())
            }
            addActionItem(menu, title: "Sponsor AeroSpace on GitHub", keyEquivalent: "") {
                NSWorkspace.shared.open(URL(string: "https://github.com/sponsors/nikitabobko").orDie())
                self.viewModel.sponsorshipMessage = sponsorshipPrompts.randomElement().orDie()
            }
            menu.addItem(.separator())
            addActionItem(menu, title: viewModel.isEnabled ? "Disable" : "Enable", keyEquivalent: "e") {
                Task.startUnstructured {
                    try await runLightSession(.menuBarButton, .forceRun) {
                        _ = await EnableCommand(args: EnableCmdArgs(rawArgs: [], targetState: .toggle))
                            .run(.defaultEnv, .emptyStdin)
                    }
                }
            }
            menu.addItem(experimentalUISettingsItem())
            addActionItem(menu, title: "Open config in '\(getTextEditorToOpenConfig().lastPathComponent)'", keyEquivalent: ",") {
                self.openConfigInEditor()
            }
            if let token: RunSessionGuard = .isServerEnabled {
                addActionItem(menu, title: "Reload config", keyEquivalent: "r") {
                    self.reloadConfig(session: token, warningsAsErrors: false)
                }
            }
        } else {
            addActionItem(menu, title: "AeroSpace requires accessibility permission to move windows", keyEquivalent: "") {
                self.viewModel.axPermissionStatus = .waitingWithPrompt
            }
        }
        addActionItem(menu, title: "Quit \(aeroSpaceAppName)", keyEquivalent: "q") {
            Task.startUnstructured {
                terminationHandler?.beforeTermination()
                terminateApp()
            }
        }
        return menu
    }

    private func reloadConfig(session: RunSessionGuard, warningsAsErrors: Bool) {
        Task.startUnstructured {
            try await runLightSession(.menuBarButton, session) {
                let args: ReloadConfigCmdArgs = ReloadConfigCmdArgs(rawArgs: []).copy(\.warningsAsErrors, warningsAsErrors)
                _ = await reloadConfig_nonCancellable(args: args)
            }
        }
    }

    private func experimentalUISettingsItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Experimental UI Settings (No stability guarantees)", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.addItem(disabledItem("Menu bar style (macOS 14 or later):"))
        for style in MenuBarStyle.allCases {
            let subItem = NSMenuItem(title: style.title, action: nil, keyEquivalent: "")
            subItem.state = viewModel.experimentalUISettings.displayStyle == style ? .on : .off
            let target = LegacyMenuActionTarget {
                    self.viewModel.experimentalUISettings.displayStyle = style
                }
            actionTargets.append(target)
            subItem.target = target
            subItem.action = #selector(LegacyMenuActionTarget.onAction)
            submenu.addItem(subItem)
        }
        item.submenu = submenu
        return item
    }

    private func openConfigInEditor() {
        let editor = getTextEditorToOpenConfig()
        let fallbackConfig: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(configDotfileName)
        switch findCustomConfigUrl() {
            case .file(let url):
                url.open(with: editor)
            case .noCustomConfigExists:
                _ = try? FileManager.default.copyItem(atPath: defaultConfigUrl.path, toPath: fallbackConfig.path)
                fallbackConfig.open(with: editor)
            case .ambiguousConfigError:
                fallbackConfig.open(with: editor)
        }
    }

    private func addActionItem(_ menu: NSMenu, title: String, systemImage: String? = nil, keyEquivalent: String = "", action: @escaping @MainActor () -> Void) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: keyEquivalent)
        item.keyEquivalentModifierMask = [.command]
        if let systemImage {
            item.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
        }
        let target = LegacyMenuActionTarget(action)
        actionTargets.append(target)
        item.target = target
        item.action = #selector(LegacyMenuActionTarget.onAction)
        menu.addItem(item)
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}

private final class LegacyMenuActionTarget: NSObject {
    private let action: @MainActor () -> Void

    init(_ action: @escaping @MainActor () -> Void) {
        self.action = action
        super.init()
    }

    @objc func onAction() {
        let action = self.action
        MainActor.assumeIsolated {
            action()
        }
    }
}

private extension NSImage {
    func resized(maxDimension: CGFloat) -> NSImage {
        let newImage = NSImage(size: NSSize(width: maxDimension, height: maxDimension))
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        let rect = NSRect(x: 0, y: 0, width: maxDimension, height: maxDimension)
        draw(in: rect, from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1)
        newImage.unlockFocus()
        return newImage
    }
}