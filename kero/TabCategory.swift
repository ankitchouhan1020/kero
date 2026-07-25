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

    var systemImage: String {
        switch self {
        case .agents: "sparkles"
        case .files: "doc.text"
        case .commands: "chevron.left.forwardslash.chevron.right"
        case .terminals: "terminal"
        }
    }

    /// Returns non-empty groups in display order while preserving tab order.
    static func groups<Value>(
        _ values: [Value],
        by category: (Value) -> Self
    ) -> [(category: Self, values: [Value])] {
        allCases.compactMap { group in
            let groupedValues = values.filter { category($0) == group }
            return groupedValues.isEmpty ? nil : (group, groupedValues)
        }
    }

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
