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

let tabs: [(id: Int, category: TabCategory)] = [
    (1, .files), (2, .agents), (3, .files), (4, .terminals)
]
let groups = TabCategory.groups(tabs, by: \.category)
assert(groups.map(\.category) == [.agents, .files, .terminals])
assert(groups.map { $0.values.map(\.id) } == [[2], [1, 3], [4]])

print("Tab category tests passed")
