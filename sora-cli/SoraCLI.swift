import Darwin
import Foundation

enum CLIError: Error, CustomStringConvertible {
    case usage(String)
    case unavailable
    case transport(String)
    case remote(SoraAutomationFailure)

    var description: String {
        switch self {
        case .usage(let message): return message
        case .unavailable:
            return "Sora local automation is unavailable. Enable it in Sora → Settings → Automation."
        case .transport(let message): return message
        case .remote(let failure): return "\(failure.code.rawValue): \(failure.message)"
        }
    }
}

struct SoraClient: Sendable {
    func send(
        _ request: SoraAutomationRequest, launchIfNeeded: Bool = true
    ) throws -> SoraAutomationResult {
        if !FileManager.default.fileExists(atPath: SoraAutomationEndpoint.socketURL.path) {
            guard launchIfNeeded else { throw CLIError.unavailable }
            launchSora()
            waitForSocket()
        }

        do {
            return try sendOnce(request)
        } catch let error as CLIError {
            guard launchIfNeeded, case .transport = error else { throw error }
            launchSora()
            waitForSocket()
            return try sendOnce(request)
        }
    }

    private func sendOnce(_ request: SoraAutomationRequest) throws -> SoraAutomationResult {
        let descriptor = try connectedSocket()
        defer { Darwin.close(descriptor) }
        let payload = try JSONEncoder().encode(request)
        var length = UInt32(payload.count).bigEndian
        guard write(Data(bytes: &length, count: 4), to: descriptor),
              write(payload, to: descriptor),
              let header = read(count: 4, from: descriptor)
        else { throw CLIError.transport("Sora closed the automation connection") }
        let responseLength = header.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        guard responseLength > 0, responseLength <= 4 * 1024 * 1024,
              let responseData = read(count: Int(responseLength), from: descriptor),
              let response = try? JSONDecoder().decode(SoraAutomationResponse.self, from: responseData)
        else { throw CLIError.transport("Sora returned an invalid automation response") }

        switch response {
        case .success(let result): return result
        case .failure(let failure): throw CLIError.remote(failure)
        }
    }

    private func launchSora() {
        let executable = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        let app = executable.deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        guard app.pathExtension == "app" else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [app.path]
        try? process.run()
        process.waitUntilExit()
    }

    private func waitForSocket() {
        for _ in 0..<50 {
            if let descriptor = try? connectedSocket() {
                Darwin.close(descriptor)
                return
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
    }

    private func connectedSocket() throws -> Int32 {
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw CLIError.transport(systemError("create socket")) }
        var noSigPipe: Int32 = 1
        _ = setsockopt(
            descriptor, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe,
            socklen_t(MemoryLayout.size(ofValue: noSigPipe))
        )

        let path = SoraAutomationEndpoint.socketURL.path
        guard path.utf8CString.count <= MemoryLayout.size(ofValue: sockaddr_un().sun_path) else {
            Darwin.close(descriptor)
            throw CLIError.transport("Sora automation socket path is too long")
        }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutablePointer(to: &address.sun_path) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: path.utf8CString.count) { destination in
                path.withCString { _ = strncpy(destination, $0, path.utf8CString.count) }
            }
        }
        let length = socklen_t(
            MemoryLayout<sockaddr_un>.offset(of: \sockaddr_un.sun_path)! + path.utf8CString.count
        )
        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(descriptor, $0, length)
            }
        }
        guard connected == 0 else {
            let error = systemError("connect to Sora")
            Darwin.close(descriptor)
            throw CLIError.transport(error)
        }
        return descriptor
    }

    private func systemError(_ action: String) -> String {
        "Failed to \(action): \(String(cString: strerror(errno)))"
    }

    private func read(count: Int, from descriptor: Int32) -> Data? {
        var data = Data(count: count)
        let received = data.withUnsafeMutableBytes { buffer -> Int in
            guard let base = buffer.baseAddress else { return 0 }
            var offset = 0
            while offset < count {
                let result = Darwin.read(descriptor, base.advanced(by: offset), count - offset)
                if result > 0 { offset += result }
                else if result < 0, errno == EINTR { continue }
                else { return -1 }
            }
            return offset
        }
        return received == count ? data : nil
    }

    private func write(_ data: Data, to descriptor: Int32) -> Bool {
        data.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else { return data.isEmpty }
            var offset = 0
            while offset < buffer.count {
                let result = Darwin.write(
                    descriptor, base.advanced(by: offset), buffer.count - offset
                )
                if result > 0 { offset += result }
                else if result < 0, errno == EINTR { continue }
                else { return false }
            }
            return true
        }
    }
}

@main
private enum SoraCLI {
    static func main() async {
        do {
            try await run(Array(CommandLine.arguments.dropFirst()))
        } catch {
            FileHandle.standardError.write(Data("sora: \(error)\n".utf8))
            Darwin.exit(error is CLIError ? 2 : 1)
        }
    }

    private static func run(_ arguments: [String]) async throws {
        guard let command = arguments.first else { throw CLIError.usage(usage) }
        let client = SoraClient()
        switch command {
        case "mcp":
            guard arguments.count == 1 else { throw CLIError.usage("Usage: sora mcp") }
            try await SoraMCP.run(client: client)
        case "status":
            guard arguments.count == 1 else { throw CLIError.usage("Usage: sora status") }
            let result = try client.send(.listProjects, launchIfNeeded: false)
            guard case .projects(let projects) = result else { throw CLIError.transport("Unexpected response") }
            print("Sora is running; local automation enabled; \(projects.count) project(s)")
        case "project":
            guard arguments == ["project", "list"] else {
                throw CLIError.usage("Usage: sora project list")
            }
            guard case .projects(let projects) = try client.send(.listProjects) else {
                throw CLIError.transport("Unexpected response")
            }
            for project in projects {
                print("\(project.id.uuidString)\t\(project.name)\t\(project.directory ?? "")")
            }
        case "open":
            guard arguments.count == 2 else { throw CLIError.usage("Usage: sora open <path>") }
            let path = absolutePath(arguments[1])
            guard case .project(let project) = try client.send(.openProject(path: path, name: nil))
            else { throw CLIError.transport("Unexpected response") }
            print("\(project.id.uuidString)\t\(project.name)\t\(project.directory ?? "")")
        case "send":
            guard (3...4).contains(arguments.count),
                  let id = UUID(uuidString: arguments[1]),
                  arguments.count == 3 || arguments[3] == "--submit"
            else { throw CLIError.usage("Usage: sora send <terminal-id> <text> [--submit]") }
            guard case .acknowledged = try client.send(.sendInput(
                terminalID: id, text: arguments[2], submit: arguments.count == 4
            )) else { throw CLIError.transport("Unexpected response") }
        case "output":
            guard arguments.count == 2 || (
                arguments.count == 4 && arguments[2] == "--lines"
                    && Int(arguments[3]) != nil
            ), let id = UUID(uuidString: arguments[1])
            else { throw CLIError.usage("Usage: sora output <terminal-id> [--lines <count>]") }
            let lines = arguments.count == 4 ? Int(arguments[3])! : 100
            guard case .output(let output) = try client.send(.readOutput(
                terminalID: id, lines: lines
            )) else { throw CLIError.transport("Unexpected response") }
            print(output)
        case "run":
            let parsed = try parseRun(Array(arguments.dropFirst()))
            guard case .terminal(let terminal) = try client.send(.spawnTerminal(
                project: parsed.project, command: parsed.command, name: parsed.name
            )) else { throw CLIError.transport("Unexpected response") }
            print("\(terminal.id.uuidString)\t\(terminal.name)\t\(terminal.directory)")
        case "help", "--help", "-h":
            print(usage)
        default:
            throw CLIError.usage(usage)
        }
    }

    private static func parseRun(
        _ arguments: [String]
    ) throws -> (project: SoraProjectReference, name: String?, command: String) {
        var project: SoraProjectReference?
        var name: String?
        var index = 0
        while index < arguments.count, arguments[index] != "--" {
            guard index + 1 < arguments.count else { throw CLIError.usage("Usage: \(runUsage)") }
            switch arguments[index] {
            case "--project":
                let value = arguments[index + 1]
                project = UUID(uuidString: value).map(SoraProjectReference.id)
                    ?? .path(absolutePath(value))
            case "--name": name = arguments[index + 1]
            default: throw CLIError.usage("Usage: \(runUsage)")
            }
            index += 2
        }
        guard let project, index < arguments.count, arguments[index] == "--",
              index + 1 < arguments.count else { throw CLIError.usage("Usage: \(runUsage)") }
        let command = arguments[(index + 1)...].map(shellQuote).joined(separator: " ")
        return (project, name, command)
    }

    private static func absolutePath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private static func shellQuote(_ argument: String) -> String {
        "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static let runUsage = "sora run --project <id-or-path> [--name <name>] -- <command> [arguments…]"
    private static let usage = """
    Usage:
      sora mcp
      sora status
      sora project list
      sora open <path>
      sora send <terminal-id> <text> [--submit]
      sora output <terminal-id> [--lines <count>]
      \(runUsage)
    """
}
