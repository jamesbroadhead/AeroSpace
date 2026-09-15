public struct ListModesCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) {
        self.commonState = .init(rawArgs)
    }
    public static let parser: CmdParser<Self> = .init(
        kind: .listModes,
        help: list_modes_help_generated,
        flags: [
            "--count": trueBoolFlag(\Self.outputOnlyCount),
            "--current": trueBoolFlag(\Self.current),
            "--json": trueBoolFlag(\Self.json),
        ],
        posArgs: [],
        conflictingOptions: [
            ["--count", "--current"],
            ["--count", "--json"],
        ],
    )

    public var current: Bool = false
    public var json: Bool = false
    public var outputOnlyCount: Bool = false
}

func parseListModesCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ListModesCmdArgs> {
    parseSpecificCmdArgs(ListModesCmdArgs(rawArgs: args), args)
}
