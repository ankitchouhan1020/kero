import Foundation

private func entry(
    _ staged: Character,
    _ unstaged: Character,
    conflict: Bool = false
) -> GitStatusModel.Entry {
    GitStatusModel.Entry(
        path: "file.swift",
        staged: staged,
        unstaged: unstaged,
        isConflict: conflict
    )
}

assert(GitStatusModel.fileDecoration(for: entry(".", "M")) == .modified)
assert(GitStatusModel.fileDecoration(for: entry("A", ".")) == .added)
assert(GitStatusModel.fileDecoration(for: entry("?", "?")) == .untracked)
assert(GitStatusModel.fileDecoration(for: entry(".", "D")) == .deleted)
assert(GitStatusModel.fileDecoration(for: entry("R", ".")) == .renamed)
assert(GitStatusModel.fileDecoration(for: entry("C", ".")) == .copied)
assert(GitStatusModel.fileDecoration(for: entry("U", "U", conflict: true)) == .conflict)
assert(GitStatusModel.FileDecoration.conflict.directoryPriority
    > GitStatusModel.FileDecoration.modified.directoryPriority)

print("Git file decoration tests passed")
