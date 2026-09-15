public struct MoveWorkspaceToMonitorCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .moveWorkspaceToMonitor,
        help: move_workspace_to_monitor_help_generated,
        flags: [
            "--wrap-around": trueBoolFlag(\Self.wrapAround),
            "--workspace": workspaceSubArgParser(keyPath: \Self.workspaceName),
        ],
        posArgs: [
            dashDashArg(keyPath: \Self.noopKeyPath, mandatory: false),
            newMandatoryPosArgParser(\Self.target, parseMonitorTarget, placeholder: MonitorTarget.cases.joinedCliArgs),
        ],
    )

    public var wrapAround: Bool = false
    public var target: Lateinit<MonitorTarget> = .uninitialized
}

func parseWorkspaceToMonitorCmdArgs(_ args: StrArrSlice) -> ParsedCmd<MoveWorkspaceToMonitorCmdArgs> {
    parseSpecificCmdArgs(MoveWorkspaceToMonitorCmdArgs(rawArgs: args), args)
        .filter("--wrap-around is incompatible with <monitor-pattern> argument") {
            $0.wrapAround.implies(!$0.target.val.isPatterns)
        }
}
