let categoryOrder = TabCategory.allCases
assert(categoryOrder == [.agents, .files, .terminals])

func category(agent: Bool = false, file: Bool = false, command: Bool = false) -> TabCategory {
    TabCategory.derive(
        hasAgentSession: agent,
        focusedIsFileOrDiff: file,
        focusedTerminalRunsCommand: command
    )
}

assert(category() == .terminals)
assert(category(command: true) == .terminals)
assert(category(file: true, command: true) == .files)
assert(category(agent: true, file: true, command: true) == .agents)

let tabs: [(id: Int, category: TabCategory)] = [
    (1, .files), (2, .agents), (3, .files), (4, .terminals)
]
let groups = TabCategory.groups(tabs, by: \.category)
assert(groups.map(\.category) == [.agents, .files, .terminals])
assert(groups.map { $0.values.map(\.id) } == [[2], [1, 3], [4]])
assert(groups.flatMap { group in group.values.map { _ in group.category } }
    == [.agents, .files, .files, .terminals]) // Every parent's children form one adjacent run.

var reordered = tabs
TabCategory.reorder(
    &reordered,
    moving: 1,
    to: 3,
    identifiedBy: \.id,
    categorizedBy: \.category
)
assert(reordered.map(\.id) == [2, 3, 1, 4])
TabCategory.reorder(
    &reordered,
    moving: 2,
    to: 1,
    identifiedBy: \.id,
    categorizedBy: \.category
)
assert(reordered.map(\.id) == [2, 3, 1, 4]) // Cross-category drag is ignored.

print("Tab category tests passed")
