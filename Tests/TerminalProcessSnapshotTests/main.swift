import Foundation

private func encoded(
    executable: String,
    padding: Int = 0,
    arguments: [String]
) -> [UInt8] {
    var argc = Int32(arguments.count).littleEndian
    var bytes = withUnsafeBytes(of: &argc) { Array($0) }
    bytes += executable.utf8
    bytes.append(0)
    bytes += repeatElement(0, count: padding)
    for argument in arguments {
        bytes += argument.utf8
        bytes.append(0)
    }
    return bytes
}

assert(TerminalProcessSnapshot.parseArguments(encoded(
    executable: "/usr/bin/env",
    padding: 2,
    arguments: ["env", "node", "agent.js"]
)) == ["env", "node", "agent.js"])
assert(TerminalProcessSnapshot.parseArguments(encoded(
    executable: "/bin/echo",
    arguments: ["echo", "hello world"]
)) == ["echo", "hello world"])
assert(TerminalProcessSnapshot.parseArguments([1, 0, 0]) == nil)
assert(TerminalProcessSnapshot.parseArguments(
    [2, 0, 0, 0] + encoded(executable: "/bin/echo", arguments: ["echo"]).dropFirst(4)
) == nil)
assert(TerminalProcessSnapshot.parseArguments([255, 255, 255, 127, 0]) == nil)
assert(TerminalProcessSnapshot.capture(shellPID: -1) == nil)

print("TerminalProcessSnapshot tests passed")
