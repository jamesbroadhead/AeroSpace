import Foundation

// todo refactor. showMessageInGui in common code looks weird
func showMessageInGui(filenameIfConsoleApp: String, title: String, message: String) {
    let titleAndMessage = "##### \(title) #####\n\n" + message
    if isCli {
        print(titleAndMessage)
    } else {
        let cachesDir = URL(fileURLWithPath: "/tmp/bobko.aerospace/")
        Result { try FileManager.default.createDirectory(at: cachesDir, withIntermediateDirectories: true) }.getOrDie()
        let file = cachesDir.appendingPathComponent(filenameIfConsoleApp)
        Result { try (titleAndMessage + "\n").write(to: file, atomically: true, encoding: .utf8) }.getOrDie()

        file.absoluteURL.open(with: URL(fileURLWithPath: "/System/Applications/Utilities/Console.app"))
    }
}
