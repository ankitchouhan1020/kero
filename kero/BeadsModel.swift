import Combine
import Dispatch
import Foundation

nonisolated struct BeadsIssue: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let description: String?
    let design: String?
    let acceptanceCriteria: String?
    let status: String
    let priority: Int
    let issueType: String
    let assignee: String?
    let owner: String?
    let labels: [String]
    let dependencies: [BeadsRelation]
    let dependents: [BeadsRelation]
    let comments: [BeadsComment]
    let parent: String?
    let dependencyCount: Int
    let dependentCount: Int
    let commentCount: Int
    let isBlocked: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, description, design, status, priority, assignee, owner
        case labels, dependencies, dependents, comments, parent
        case acceptanceCriteria = "acceptance_criteria"
        case issueType = "issue_type"
        case dependencyCount = "dependency_count"
        case dependentCount = "dependent_count"
        case commentCount = "comment_count"
        case isBlocked = "is_blocked"
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        description = try values.decodeIfPresent(String.self, forKey: .description)
        design = try values.decodeIfPresent(String.self, forKey: .design)
        acceptanceCriteria = try values.decodeIfPresent(String.self, forKey: .acceptanceCriteria)
        status = try values.decode(String.self, forKey: .status)
        priority = try values.decodeIfPresent(Int.self, forKey: .priority) ?? 2
        issueType = try values.decodeIfPresent(String.self, forKey: .issueType) ?? "task"
        assignee = try values.decodeIfPresent(String.self, forKey: .assignee)
        owner = try values.decodeIfPresent(String.self, forKey: .owner)
        labels = try values.decodeIfPresent([String].self, forKey: .labels) ?? []
        dependencies = try values.decodeIfPresent([BeadsRelation].self, forKey: .dependencies) ?? []
        dependents = try values.decodeIfPresent([BeadsRelation].self, forKey: .dependents) ?? []
        comments = try values.decodeIfPresent([BeadsComment].self, forKey: .comments) ?? []
        parent = try values.decodeIfPresent(String.self, forKey: .parent)
        dependencyCount = try values.decodeIfPresent(Int.self, forKey: .dependencyCount) ?? dependencies.count
        dependentCount = try values.decodeIfPresent(Int.self, forKey: .dependentCount) ?? dependents.count
        commentCount = try values.decodeIfPresent(Int.self, forKey: .commentCount) ?? comments.count
        isBlocked = (try values.decodeIfPresent(Bool.self, forKey: .isBlocked)) ?? (status == "blocked")
    }
}

nonisolated struct BeadsRelation: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let title: String?
    let status: String?
    let dependencyType: String?

    enum CodingKeys: String, CodingKey {
        case id, title, status
        case dependencyType = "dependency_type"
        case type
        case issueID = "issue_id"
        case dependsOnID = "depends_on_id"
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id)
            ?? values.decodeIfPresent(String.self, forKey: .dependsOnID)
            ?? values.decode(String.self, forKey: .issueID)
        title = try values.decodeIfPresent(String.self, forKey: .title)
        status = try values.decodeIfPresent(String.self, forKey: .status)
        dependencyType = try values.decodeIfPresent(String.self, forKey: .dependencyType)
            ?? values.decodeIfPresent(String.self, forKey: .type)
    }
}

nonisolated struct BeadsComment: Decodable, Identifiable, Equatable, Sendable {
    let id: Int
    let author: String?
    let text: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, author, text, body, createdAt = "created_at"
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(Int.self, forKey: .id) ?? 0
        author = try values.decodeIfPresent(String.self, forKey: .author)
        text = try values.decodeIfPresent(String.self, forKey: .text)
            ?? values.decodeIfPresent(String.self, forKey: .body) ?? ""
        createdAt = try values.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

nonisolated enum BeadsCommand {
    struct Result: Sendable {
        let status: Int32
        let stdout: String
        let stderr: String
    }

    static func executable(configuredPath: String, environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        let candidates = [configuredPath, "/opt/homebrew/bin/bd", "/usr/local/bin/bd"]
            + (environment["PATH"] ?? "").split(separator: ":").map { String($0) + "/bd" }
        return candidates.first { !$0.isEmpty && FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func run(executable: String, root: String, arguments: [String]) -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["-C", root] + arguments
        process.currentDirectoryURL = URL(fileURLWithPath: root, isDirectory: true)
        process.standardInput = FileHandle.nullDevice
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
        } catch {
            return Result(status: -1, stdout: "", stderr: error.localizedDescription)
        }
        let output = PipeData()
        let errors = PipeData()
        let readers = DispatchGroup()
        readers.enter()
        DispatchQueue.global(qos: .utility).async {
            output.value = stdout.fileHandleForReading.readDataToEndOfFile()
            readers.leave()
        }
        readers.enter()
        DispatchQueue.global(qos: .utility).async {
            errors.value = stderr.fileHandleForReading.readDataToEndOfFile()
            readers.leave()
        }
        process.waitUntilExit()
        readers.wait()
        return Result(
            status: process.terminationStatus,
            stdout: String(data: output.value, encoding: .utf8) ?? "",
            stderr: String(data: errors.value, encoding: .utf8) ?? ""
        )
    }
}

@MainActor final class BeadsModel: nonisolated ObservableObject {
    @Published private(set) var rootPath = ""
    @Published private(set) var workspacePath: String?
    @Published private(set) var issues: [BeadsIssue] = []
    @Published private(set) var readyIDs: Set<String> = []
    @Published private(set) var blockedIDs: Set<String> = []
    @Published private(set) var detail: BeadsIssue?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isLoadingDetail = false
    @Published private(set) var isBusy = false
    @Published private(set) var hasResolved = false
    @Published private(set) var error: String?
    @Published private(set) var operationResult: String?

    private var generation = 0
    private var requestID = 0
    private var lastRefresh = Date.distantPast

    func sync(root: String, executablePath: String) {
        let rootChanged = root != rootPath
        if rootChanged {
            generation &+= 1
            rootPath = root
            workspacePath = nil
            issues = []
            readyIDs = []
            blockedIDs = []
            detail = nil
            error = nil
            operationResult = nil
            isRefreshing = false
            isLoadingDetail = false
            isBusy = false
            hasResolved = false
            lastRefresh = .distantPast
        }
        refresh(executablePath: executablePath, force: rootChanged)
    }

    func refresh(executablePath: String, force: Bool = true) {
        guard !rootPath.isEmpty, !isRefreshing, !isBusy,
              force || Date().timeIntervalSince(lastRefresh) >= 8 else { return }
        let root = rootPath
        let generation = generation
        requestID &+= 1
        let requestID = requestID
        isRefreshing = true
        Task { [weak self] in
            let result = await Task.detached(priority: .utility) {
                Self.load(root: root, configuredPath: executablePath)
            }.value
            guard let self, self.generation == generation,
                  self.requestID == requestID, self.rootPath == root else { return }
            self.isRefreshing = false
            self.hasResolved = true
            self.lastRefresh = Date()
            switch result {
            case .success(let snapshot):
                self.workspacePath = snapshot.workspacePath
                self.issues = snapshot.issues
                self.readyIDs = snapshot.readyIDs
                self.blockedIDs = snapshot.blockedIDs
                self.error = nil
                if let selected = self.detail?.id,
                   !snapshot.issues.contains(where: { $0.id == selected }) {
                    self.detail = nil
                }
            case .failure(let error):
                self.workspacePath = nil
                self.issues = []
                self.readyIDs = []
                self.blockedIDs = []
                self.error = error.localizedDescription
            }
        }
    }

    func loadDetail(id: String, executablePath: String) {
        guard workspacePath != nil, !isLoadingDetail else { return }
        let root = rootPath
        let generation = generation
        isLoadingDetail = true
        detail = nil
        Task { [weak self] in
            let result = await Task.detached(priority: .utility) {
                Self.commandIssues(root: root, configuredPath: executablePath,
                    arguments: ["show", id, "--json", "--include-comments", "--include-dependents"])
            }.value
            guard let self, self.generation == generation, self.rootPath == root else { return }
            self.isLoadingDetail = false
            switch result {
            case .success(let issues):
                self.detail = issues.first
                self.error = issues.first == nil ? "Beads returned no details for \(id)." : nil
            case .failure(let error): self.error = error.localizedDescription
            }
        }
    }

    func claim(_ issue: BeadsIssue, executablePath: String) {
        perform(issue, label: "Claimed \(issue.id)", executablePath: executablePath,
                arguments: ["update", issue.id, "--claim", "--json"])
    }

    func close(_ issue: BeadsIssue, executablePath: String) {
        perform(issue, label: "Closed \(issue.id)", executablePath: executablePath,
                arguments: ["close", issue.id, "--json"])
    }

    func reopen(_ issue: BeadsIssue, executablePath: String) {
        perform(issue, label: "Reopened \(issue.id)", executablePath: executablePath,
                arguments: ["reopen", issue.id, "--json"])
    }

    func clearDetail() { detail = nil }
    func dismissOperation() { operationResult = nil }

    private func perform(_ issue: BeadsIssue, label: String, executablePath: String, arguments: [String]) {
        guard workspacePath != nil, issues.contains(where: { $0.id == issue.id }), !isBusy else {
            error = "The issue or project changed. Refresh and try again."
            return
        }
        let root = rootPath
        let generation = generation
        isBusy = true
        error = nil
        operationResult = nil
        Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                Self.run(root: root, configuredPath: executablePath, arguments: arguments)
            }.value
            guard let self, self.generation == generation, self.rootPath == root else { return }
            self.isBusy = false
            switch result {
            case .success: self.operationResult = label
            case .failure(let error): self.error = error.localizedDescription
            }
            self.refresh(executablePath: executablePath)
            if self.detail?.id == issue.id {
                self.loadDetail(id: issue.id, executablePath: executablePath)
            }
        }
    }

    private nonisolated struct Snapshot: Sendable {
        let workspacePath: String?
        let issues: [BeadsIssue]
        let readyIDs: Set<String>
        let blockedIDs: Set<String>
    }

    private nonisolated struct Workspace: Decodable { let path: String }
    private nonisolated enum LoadError: LocalizedError {
        case missingExecutable
        case command(String)
        case decoding(String)
        var errorDescription: String? {
            switch self {
            case .missingExecutable: return "Beads CLI not found. Install bd or set beads.executable in Sora Settings."
            case .command(let message): return message
            case .decoding(let message): return "Unable to read Beads data: \(message)"
            }
        }
    }

    private nonisolated static func load(root: String, configuredPath: String) -> Result<Snapshot, Error> {
        guard let executable = BeadsCommand.executable(configuredPath: configuredPath) else {
            return .failure(LoadError.missingExecutable)
        }
        let whereResult = BeadsCommand.run(executable: executable, root: root, arguments: ["where", "--json"])
        guard whereResult.status == 0 else {
            return .success(Snapshot(workspacePath: nil, issues: [], readyIDs: [], blockedIDs: []))
        }
        let workspace: Workspace
        do { workspace = try JSONDecoder().decode(Workspace.self, from: Data(whereResult.stdout.utf8)) }
        catch { return .failure(LoadError.decoding(error.localizedDescription)) }
        let list = commandIssues(executable: executable, root: root, arguments: ["list", "--all", "--json", "--limit", "0"])
        let ready = commandIssues(executable: executable, root: root, arguments: ["ready", "--json", "--limit", "0"])
        let blocked = commandIssues(executable: executable, root: root, arguments: ["blocked", "--json"])
        switch (list, ready, blocked) {
        case (.success(let issues), .success(let readyIssues), .success(let blockedIssues)):
            return .success(Snapshot(
                workspacePath: workspace.path,
                issues: issues,
                readyIDs: Set(readyIssues.map(\.id)),
                blockedIDs: Set(blockedIssues.map(\.id))
            ))
        case (.failure(let error), _, _), (_, .failure(let error), _), (_, _, .failure(let error)):
            return .failure(error)
        }
    }

    private nonisolated static func commandIssues(root: String, configuredPath: String, arguments: [String]) -> Result<[BeadsIssue], Error> {
        guard let executable = BeadsCommand.executable(configuredPath: configuredPath) else {
            return .failure(LoadError.missingExecutable)
        }
        return commandIssues(executable: executable, root: root, arguments: arguments)
    }

    private nonisolated static func commandIssues(executable: String, root: String, arguments: [String]) -> Result<[BeadsIssue], Error> {
        switch run(executable: executable, root: root, arguments: arguments) {
        case .failure(let error): return .failure(error)
        case .success(let output):
            do { return .success(try JSONDecoder().decode([BeadsIssue].self, from: Data(output.utf8))) }
            catch { return .failure(LoadError.decoding(error.localizedDescription)) }
        }
    }

    private nonisolated static func run(root: String, configuredPath: String, arguments: [String]) -> Result<String, Error> {
        guard let executable = BeadsCommand.executable(configuredPath: configuredPath) else {
            return .failure(LoadError.missingExecutable)
        }
        return run(executable: executable, root: root, arguments: arguments)
    }

    private nonisolated static func run(executable: String, root: String, arguments: [String]) -> Result<String, Error> {
        let result = BeadsCommand.run(executable: executable, root: root, arguments: arguments)
        guard result.status == 0 else {
            return .failure(LoadError.command(commandMessage(result, fallback: "bd command failed.")))
        }
        return .success(result.stdout)
    }

    private nonisolated static func commandMessage(_ result: BeadsCommand.Result, fallback: String) -> String {
        let text = [result.stderr, result.stdout]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        return text ?? fallback
    }
}

private nonisolated final class PipeData: @unchecked Sendable {
    var value = Data()
}
