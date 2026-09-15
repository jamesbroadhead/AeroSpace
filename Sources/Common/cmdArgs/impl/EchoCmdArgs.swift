public struct EchoCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .echo,
        help: echo_help_generated,
        flags: [
            "--stderr": trueBoolFlag(\Self.isStderr),
            "--window-id": windowIdSubArgParser(keyPath: \Self.windowId),
        ],
        posArgs: [
            dashDashArg(keyPath: \Self.noopKeyPath, mandatory: true),
            newMandatoryPosArgParser(\Self.args, consumeWholeArrayOfInterpolatedPosArgs, placeholder: "<string>"),
        ],
        conflictingOptions: [],
    )

    public var args: Lateinit<[[InterToken<InterVar>]]> = .uninitialized
    public var isStderr: Bool = false
}

private func consumeWholeArrayOfInterpolatedPosArgs(i: PosArgParserInput) -> ParsedCliArgs<[[InterToken<InterVar>]]> {
    let args = i.args.slice(i.index...).orDie().toArray()
    let interVars = args.mapAllOrFailure { arg in
        arg.interpolationTokens(interpolationChar: "%", ofInterVarType: InterVar.self)
    }
    return .init(interVars, advanceBy: args.count)
}
