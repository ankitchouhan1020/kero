let categoryOrder = TabCategory.allCases
assert(categoryOrder == [.agents, .files, .commands, .terminals])

func category(agent: Bool = false, file: Bool = false, command: Bool = false) -> TabCategory {
    TabCategory.derive(
        hasAgentSession: agent,
        focusedIsFileOrDiff: file,
        focusedTerminalRunsCommand: command
    )
}

assert(category() == .terminals)
assert(category(command: true) == .commands)
assert(category(file: true, command: true) == .files)
assert(category(agent: true, file: true, command: true) == .agents)

// Filtering the canonical tab order preserves order within every category.
let tabs: [(Int, TabCategory)] = [(1, .files), (2, .agents), (3, .files), (4, .terminals)]
assert(categoryOrder.map { group in tabs.filter { $0.1 == group }.map(\.0) } == [[2], [1, 3], [], [4]])

print("Tab category tests passed")
