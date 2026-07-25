import Darwin
import Foundation

private func snapshot(_ name: String, group: pid_t = 20) -> TerminalProcessSnapshot {
    TerminalProcessSnapshot(
        processGroupID: group,
        members: [.init(pid: group, name: name, argv: [name])]
    )
}

assert(TerminalActivity.classify(
    shellPID: 10, foregroundPID: 10, snapshot: snapshot("zsh", group: 10)
) == .terminal)
assert(TerminalActivity.classify(
    shellPID: 10, foregroundPID: 20, snapshot: snapshot("claude")
) == .agent(.claude))
assert(TerminalActivity.classify(
    shellPID: 10, foregroundPID: 20, snapshot: snapshot("git")
) == .command)

var tracker = TerminalActivityTracker()
assert(tracker.observe(.agent(.claude)) == nil)
assert(tracker.observe(.agent(.claude)) == .agent(.claude))
assert(tracker.observe(.command) == nil)
assert(tracker.activity == .agent(.claude))
assert(tracker.observe(.agent(.claude)) == nil)
assert(tracker.observe(.terminal) == nil)
assert(tracker.observe(.terminal) == .terminal)

print("Terminal activity tests passed")
