import Foundation

let fixture = Data(#"""
[
  {
    "id": "sora-1",
    "title": "Ready issue",
    "description": "Do the work",
    "acceptance_criteria": "It works",
    "status": "open",
    "priority": 1,
    "issue_type": "task",
    "labels": ["agent"],
    "dependencies": [{"id":"sora-0","title":"Parent","status":"closed","dependency_type":"blocks"}],
    "dependent_count": 1,
    "comment_count": 0,
    "future_field": true
  },
  {
    "id": "sora-2",
    "title": "Blocked issue",
    "status": "blocked",
    "priority": 2,
    "issue_type": "bug",
    "is_blocked": true
  }
]
"""#.utf8)

let issues = try JSONDecoder().decode([BeadsIssue].self, from: fixture)
assert(issues.count == 2)
assert(issues[0].acceptanceCriteria == "It works")
assert(issues[0].labels == ["agent"])
assert(issues[0].dependencies.first?.id == "sora-0")
assert(issues[1].isBlocked)
assert(issues[1].dependencies.isEmpty)

let malformed = Data("[{\"title\":\"missing id\"}]".utf8)
assert((try? JSONDecoder().decode([BeadsIssue].self, from: malformed)) == nil)

let temporary = FileManager.default.temporaryDirectory
    .appendingPathComponent("sora-beads-tests-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
let fakeBD = temporary.appendingPathComponent("bd")
try "#!/bin/sh\nprintf 'args:%s' \"$*\"\nprintf 'warning' >&2\nexit 7\n".write(to: fakeBD, atomically: true, encoding: .utf8)
try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeBD.path)
defer { try? FileManager.default.removeItem(at: temporary) }

assert(BeadsCommand.executable(configuredPath: fakeBD.path, environment: ["PATH": ""]) == fakeBD.path)
let command = BeadsCommand.run(executable: fakeBD.path, root: temporary.path, arguments: ["list", "--json"])
assert(command.status == 7)
assert(command.stdout.contains("-C \(temporary.path) list --json"))
assert(command.stderr == "warning")

print("Beads model tests passed")
