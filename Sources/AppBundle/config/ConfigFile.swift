import Common
import Foundation

let configDotfileName = ".aerospace.toml"
func findCustomConfigUrl() -> ConfigFile {
    let xdgConfigHome = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"].map { URL(fileURLWithPath: $0) }
        ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/")
    let candidates: [URL] = switch serverArgs.configLocation {
        case let configLocation?: [URL(fileURLWithPath: configLocation)]
        case nil:
            [
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(configDotfileName),
                xdgConfigHome.appendingPathComponent("aerospace").appendingPathComponent("aerospace.toml"),
            ]
    }
    let existingCandidates: [URL] = candidates.filter { (candidate: URL) in FileManager.default.fileExists(atPath: candidate.path) }
    let count = existingCandidates.count
    return switch count {
        case 0: .noCustomConfigExists
        case 1: .file(existingCandidates.first.orDie())
        default: .ambiguousConfigError(existingCandidates)
    }
}

enum ConfigFile {
    case file(URL), ambiguousConfigError(_ candidates: [URL]), noCustomConfigExists

    var urlOrNil: URL? {
        return switch self {
            case .file(let url): url
            case .ambiguousConfigError, .noCustomConfigExists: nil
        }
    }
}
