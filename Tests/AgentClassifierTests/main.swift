import Darwin
import Foundation

private func snapshot(_ members: [(pid_t, String, [String]?)], group: pid_t = 20) -> TerminalProcessSnapshot {
    TerminalProcessSnapshot(
        processGroupID: group,
        members: members.map(TerminalProcessSnapshot.Member.init)
    )
}

let direct: [(String, AgentKind)] = [
    ("claude", .claude),
    ("codex", .codex),
    ("gemini", .gemini),
    ("grok", .grok),
    ("pi", .pi),
    ("cursor-agent", .cursorAgent),
    ("opencode", .openCode),
    ("copilot", .copilot),
    ("kimi", .kimi),
    ("amp", .amp),
]
for (alias, kind) in direct {
    assert(snapshot([(20, alias, ["/usr/local/bin/\(alias)"])]).agentKind == kind)
}

assert(snapshot([(20, "agent", ["agent"])]).agentKind == nil)
let symlinkDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent("sora-agent-classifier-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: symlinkDirectory, withIntermediateDirectories: true)
let cursorExecutable = symlinkDirectory.appendingPathComponent("cursor-agent")
let genericAgentLink = symlinkDirectory.appendingPathComponent("agent")
try Data().write(to: cursorExecutable)
try FileManager.default.createSymbolicLink(
    atPath: genericAgentLink.path, withDestinationPath: cursorExecutable.path
)
defer { try? FileManager.default.removeItem(at: symlinkDirectory) }
assert(snapshot([(20, "agent", [genericAgentLink.path])]).agentKind == .cursorAgent)
assert(snapshot([(20, "github-copilot", ["github-copilot"])]).agentKind == .copilot)
assert(snapshot([(20, "kimi-cli", ["kimi-cli"])]).agentKind == .kimi)
assert(snapshot([(20, "node", ["node", "/opt/homebrew/bin/claude"])]).agentKind == .claude)
assert(snapshot([(20, "bun", ["bun", "/opt/homebrew/bin/gemini"])]).agentKind == .gemini)
assert(snapshot([(20, "python3.13", ["python3.13", "--", "/usr/local/bin/kimi"])]).agentKind == .kimi)
assert(snapshot([(20, "zsh", ["zsh", "/usr/local/bin/codex"])]).agentKind == .codex)

assert(snapshot([
    (19, "claude", ["claude"]),
    (20, "codex", ["codex"]),
]).agentKind == .codex)
assert(snapshot([
    (20, "node", ["node", "server.js"]),
    (21, "amp", ["amp"]),
]).agentKind == .amp)

for (name, argv) in [
    ("zsh", ["zsh"]),
    ("git", ["git", "status"]),
    ("node", ["node", "my-codex-helper.js"]),
    ("bash", ["bash", "-lc", "claude"]),
    ("node", ["node", "--eval", "gemini"]),
    ("python3", ["python3", "-m", "opencode"]),
] {
    assert(snapshot([(20, name, argv)]).agentKind == nil)
}

print("Agent classifier tests passed")
