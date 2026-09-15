import Foundation

/// Case-insensitive regex wrapper using NSRegularExpression (macOS 10+).
/// https://github.com/swiftlang/swift-experimental-string-processing/issues/792
/// https://forums.swift.org/t/should-regex-be-sendable/69529
public struct CaseInsensitiveRegex: Equatable, Sendable {
    public let origin: String
    fileprivate let regex: NSRegularExpression

    private init(_ origin: String, _ regex: NSRegularExpression) {
        self.origin = origin
        self.regex = regex
    }

    public static func new(_ str: String) -> ResOrStr<CaseInsensitiveRegex> {
        Result { try NSRegularExpression(pattern: str, options: [.caseInsensitive]) }
            .mapError { e in "Can't parse \(str.singleQuoted) regex: \(e.localizedDescription)" }
            .map { CaseInsensitiveRegex(str, $0) }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.origin == rhs.origin }
}

extension String {
    @MainActor public func contains(caseInsensitiveRegex regex: CaseInsensitiveRegex) -> Bool {
        let range = NSRange(location: 0, length: utf16.count)
        return regex.regex.firstMatch(in: self, options: [], range: range) != nil
    }
}
