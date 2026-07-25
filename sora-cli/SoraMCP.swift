import Foundation
import MCP

struct SoraMCP {
    static func run(client: SoraClient) async throws {
        let server = Server(
            name: "sora",
            version: "1.0",
            capabilities: .init(tools: .init())
        )

        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: tools)
        }
        await server.withMethodHandler(CallTool.self) { parameters in
            await call(parameters, client: client)
        }

        try await server.start(transport: StdioTransport())
        await server.waitUntilCompleted()
        await server.stop()
    }

    private static func call(
        _ parameters: CallTool.Parameters, client: SoraClient
    ) async -> CallTool.Result {
        let arguments = parameters.arguments ?? [:]
        do {
            switch parameters.name {
            case "sora_list_projects":
                return try result(client.send(.listProjects))
            case "sora_open_project":
                guard let path = arguments["path"]?.stringValue else {
                    return failure(.invalidRequest, "path is required")
                }
                return try result(client.send(.openProject(
                    path: absolutePath(path), name: arguments["name"]?.stringValue
                )))
            case "sora_spawn_terminal":
                guard let project = arguments["project"]?.stringValue else {
                    return failure(.invalidRequest, "project is required")
                }
                return try result(client.send(.spawnTerminal(
                    project: projectReference(project),
                    command: arguments["command"]?.stringValue,
                    name: arguments["name"]?.stringValue
                )))
            case "sora_send_input":
                guard let id = uuid(arguments, "terminal_id"),
                      let text = arguments["text"]?.stringValue
                else { return failure(.invalidRequest, "terminal_id and text are required") }
                return try result(client.send(.sendInput(
                    terminalID: id, text: text,
                    submit: arguments["submit"]?.boolValue ?? false
                )))
            case "sora_read_output":
                guard let id = uuid(arguments, "terminal_id") else {
                    return failure(.invalidRequest, "terminal_id is required")
                }
                return try result(client.send(.readOutput(
                    terminalID: id, lines: arguments["lines"]?.intValue ?? 100
                )))
            case "sora_close_terminal":
                guard let id = uuid(arguments, "terminal_id") else {
                    return failure(.invalidRequest, "terminal_id is required")
                }
                return try result(client.send(.closeTerminal(id: id)))
            default:
                return failure(.invalidRequest, "Unknown tool: \(parameters.name)")
            }
        } catch CLIError.remote(let error) {
            return failure(error.code, error.message)
        } catch {
            return failure(.internalError, String(describing: error))
        }
    }

    private static func result(_ result: SoraAutomationResult) throws -> CallTool.Result {
        let value: Value
        switch result {
        case .projects(let projects):
            value = .object(["projects": .array(projects.map(projectValue))])
        case .project(let project):
            value = .object(["project": projectValue(project)])
        case .terminal(let terminal):
            value = .object(["terminal": terminalValue(terminal)])
        case .output(let output):
            value = .object(["output": .string(output)])
        case .acknowledged:
            value = .object(["ok": .bool(true)])
        }
        return .init(
            content: [.text(text: json(value), annotations: nil, _meta: nil)],
            structuredContent: Optional.some(value),
            isError: false
        )
    }

    private static func failure(
        _ code: SoraAutomationFailure.Code, _ message: String
    ) -> CallTool.Result {
        let value: Value = .object(["error": .object([
            "code": .string(code.rawValue), "message": .string(message),
        ])])
        return .init(
            content: [.text(text: json(value), annotations: nil, _meta: nil)],
            structuredContent: Optional.some(value),
            isError: true
        )
    }

    private static func projectValue(_ project: SoraProjectSummary) -> Value {
        .object([
            "id": .string(project.id.uuidString),
            "name": .string(project.name),
            "directory": project.directory.map(Value.string) ?? .null,
            "selected": .bool(project.selected),
        ])
    }

    private static func terminalValue(_ terminal: SoraTerminalSummary) -> Value {
        .object([
            "id": .string(terminal.id.uuidString),
            "project_id": .string(terminal.projectID.uuidString),
            "name": .string(terminal.name),
            "directory": .string(terminal.directory),
            "exited": .bool(terminal.exited),
        ])
    }

    private static func uuid(_ arguments: [String: Value], _ key: String) -> UUID? {
        arguments[key]?.stringValue.flatMap(UUID.init(uuidString:))
    }

    private static func projectReference(_ value: String) -> SoraProjectReference {
        UUID(uuidString: value).map(SoraProjectReference.id)
            ?? .path(absolutePath(value))
    }

    private static func absolutePath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private static func json(_ value: Value) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try! encoder.encode(value), as: UTF8.self)
    }

    private static let tools: [Tool] = [
        tool("sora_list_projects", "List projects open in Sora"),
        tool("sora_open_project", "Open or select a project directory in Sora", properties: [
            "path": string("Absolute or relative directory path"),
            "name": string("Optional project name"),
        ], required: ["path"]),
        tool("sora_spawn_terminal", "Open a visible terminal tab in a Sora project", properties: [
            "project": string("Project UUID or directory path"),
            "command": string("Optional shell command to run"),
            "name": string("Optional terminal tab name"),
        ], required: ["project"]),
        tool("sora_send_input", "Send text to a live Sora terminal", properties: [
            "terminal_id": string("Terminal UUID"),
            "text": string("Text to send"),
            "submit": .object(["type": "boolean", "description": "Also send Enter"]),
        ], required: ["terminal_id", "text"]),
        tool("sora_read_output", "Read the bounded rendered tail of a Sora terminal", properties: [
            "terminal_id": string("Terminal UUID"),
            "lines": .object(["type": "integer", "description": "Lines to return (1–500)"]),
        ], required: ["terminal_id"]),
        tool("sora_close_terminal", "Close a Sora terminal tab", properties: [
            "terminal_id": string("Terminal UUID"),
        ], required: ["terminal_id"]),
    ]

    private static func tool(
        _ name: String, _ description: String,
        properties: [String: Value] = [:], required: [String] = []
    ) -> Tool {
        Tool(
            name: name,
            description: description,
            inputSchema: .object([
                "type": "object",
                "properties": .object(properties),
                "required": .array(required.map(Value.string)),
                "additionalProperties": false,
            ])
        )
    }

    private static func string(_ description: String) -> Value {
        .object(["type": "string", "description": .string(description)])
    }
}
