//
//  TabCategory.swift
//  kero
//

/// Activity groups in their display order.
nonisolated enum TabCategory: String, CaseIterable {
    case agents = "Agents"
    case files = "Files"
    case commands = "Commands"
    case terminals = "Terminals"

    /// A tab belongs to one group. Agent work anywhere in a split wins;
    /// otherwise only the focused pane determines its activity group.
    static func derive(
        hasAgentSession: Bool,
        focusedIsFileOrDiff: Bool,
        focusedTerminalRunsCommand: Bool
    ) -> Self {
        if hasAgentSession { return .agents }
        if focusedIsFileOrDiff { return .files }
        if focusedTerminalRunsCommand { return .commands }
        return .terminals
    }
}
