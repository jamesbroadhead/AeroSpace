public struct ListMonitorsCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .listMonitors,
        help: list_monitors_help_generated,
        flags: [
            "--focused": boolFlag(\Self.focused),
            "--mouse": boolFlag(\Self.mouse),

            // Formatting flags
            "--format": formatParser(\Self._format, for: .monitor),
            "--count": trueBoolFlag(\Self.outputOnlyCount),
            "--json": trueBoolFlag(\Self.json),
        ],
        posArgs: [],
        conflictingOptions: [
            ["--count", "--format"],
            ["--count", "--json"],
        ],
    )

    public var focused: Bool?
    public var mouse: Bool?
    public var _format: [InterToken<InterVar>] = []
    public var outputOnlyCount: Bool = false
    public var json: Bool = false
}

extension ListMonitorsCmdArgs {
    public var format: [InterToken<InterVar>] {
        _format.isEmpty
            ? [
                .interVar(.formatVar(.monitor(.monitorId_oneBased))), .interVar(.plainInterVar(.rightPadding)), .literal(" | "),
                .interVar(.formatVar(.monitor(.monitorName))),
            ]
            : _format
    }
}

func parseListMonitorsCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ListMonitorsCmdArgs> {
    parseSpecificCmdArgs(ListMonitorsCmdArgs(rawArgs: args), args)
        .flatMap { if $0.json, let msg = getErrorIfFormatIsIncompatibleWithJson($0._format) { .failure(msg) } else { .cmd($0) } }
}
