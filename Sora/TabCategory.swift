//
//  TabCategory.swift
//  sora
//

/// Activity groups in their display order.
nonisolated enum TabCategory: String, CaseIterable {
    case agents = "Agents"
    case files = "Files"
    case terminals = "Terminals"

    var systemImage: String {
        switch self {
        case .agents: "sparkles"
        case .files: "doc.text"
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

    /// Reorders only within a derived category, preserving the canonical tab
    /// array used by keyboard navigation and close-to-the-right actions.
    static func reorder<Value, ID: Equatable>(
        _ values: inout [Value],
        moving sourceID: ID,
        to targetID: ID,
        identifiedBy id: (Value) -> ID,
        categorizedBy category: (Value) -> Self
    ) {
        guard sourceID != targetID,
              let sourceIndex = values.firstIndex(where: { id($0) == sourceID }),
              let targetIndex = values.firstIndex(where: { id($0) == targetID }),
              category(values[sourceIndex]) == category(values[targetIndex])
        else { return }

        let value = values.remove(at: sourceIndex)
        values.insert(value, at: targetIndex)
    }

    /// A tab belongs to one group. Agent work anywhere in a split wins;
    /// otherwise files split out and terminal/command panes stay together.
    static func derive(
        hasAgentSession: Bool,
        focusedIsFileOrDiff: Bool,
        focusedTerminalRunsCommand: Bool
    ) -> Self {
        if hasAgentSession { return .agents }
        if focusedIsFileOrDiff { return .files }
        return .terminals
    }
}
