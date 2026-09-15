private let focusFollowsMouseParserTable: [String: any ParserProtocol] = [
    "enabled": Parser(\FocusFollowsMouse.enabled, parseBool),
]

func parseFocusFollowsMouse(_ rawConfig: OrderedJson, _ backtrace: ConfigBacktrace, _ c: inout ConfigParserContext) -> FocusFollowsMouse {
    parseTable(rawConfig, FocusFollowsMouse(), focusFollowsMouseParserTable, backtrace, &c)
}
