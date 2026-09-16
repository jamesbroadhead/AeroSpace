import AppKit
import Common
import ServiceManagement

@MainActor
func syncStartAtLogin() {
    FileLog.log("syncStartAtLogin startAtLogin=\(config.startAtLogin)")
    if #available(macOS 13, *) {
        let service = SMAppService.mainApp
        switch true {
            case !config.startAtLogin: _ = try? service.unregister()
            case isDebug: print("'start-at-login = true' has no effect in debug builds")
            default: _ = try? service.register()
        }
    } else {
        syncStartAtLoginViaLaunchAgent()
    }
}

@MainActor
private func syncStartAtLoginViaLaunchAgent() { // pre-macOS 13 fallback: handcrafted LaunchAgent plist
    let launchAgentsDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/")
    Result { try FileManager.default.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true) }.getOrDie()
    let url: URL = launchAgentsDir.appendingPathComponent("\(aeroSpaceAppId).plist")
    if config.startAtLogin {
        guard !isDebug else {
            print("'start-at-login = true' has no effect in debug builds")
            return
        }
        let executablePath = (ProcessInfo.processInfo.arguments.first.map { URL(fileURLWithPath: $0) })?
            .absoluteURL.path ?? dieT("Can't get executable path")
        let plist =
            """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>\(aeroSpaceAppId)</string>
                <key>ProgramArguments</key>
                <array>
                    <string>\(executablePath)</string>
                    <string>--started-at-login</string>
                </array>
                <key>RunAtLoad</key>
                <true/>
            </dict>
            </plist>
            """
        if plist != (try? String(contentsOf: url)) {
            Result { try plist.write(to: url, atomically: false, encoding: .utf8) }.getOrDie("Can't write to \(url) ")
        }
    } else {
        try? FileManager.default.removeItem(at: url)
    }
}