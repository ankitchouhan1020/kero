import Foundation

/// Codable messages shared by Sora's app-side control layer and its bundled helper.
nonisolated enum SoraAutomationEndpoint {
    #if DEBUG
    static let helperIdentifier = "dev.ankitchouhan.sora.dev.helper"
    private static let directoryName = "sora-dev"
    #else
    static let helperIdentifier = "dev.ankitchouhan.sora.helper"
    private static let directoryName = "sora"
    #endif

    static let socketURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support", isDirectory: true)
        .appendingPathComponent(directoryName, isDirectory: true)
        .appendingPathComponent("automation.sock")
}

nonisolated enum SoraAutomationRequest: Codable, Equatable {
    case listProjects
    case openProject(path: String, name: String?)
    case selectProject(id: UUID)
    case spawnTerminal(project: SoraProjectReference, command: String?, name: String?)
    case sendInput(terminalID: UUID, text: String, submit: Bool)
    case readOutput(terminalID: UUID, lines: Int)
    case closeTerminal(id: UUID)
}

nonisolated struct SoraProjectReference: Codable, Equatable {
    var id: UUID?
    var path: String?

    static func id(_ id: UUID) -> Self { Self(id: id, path: nil) }
    static func path(_ path: String) -> Self { Self(id: nil, path: path) }
}

nonisolated enum SoraAutomationResponse: Codable, Equatable {
    case success(SoraAutomationResult)
    case failure(SoraAutomationFailure)
}

nonisolated enum SoraAutomationResult: Codable, Equatable {
    case projects([SoraProjectSummary])
    case project(SoraProjectSummary)
    case terminal(SoraTerminalSummary)
    case output(String)
    case acknowledged
}

nonisolated struct SoraProjectSummary: Codable, Equatable {
    var id: UUID
    var windowID: UUID
    var name: String
    var directory: String?
    var selected: Bool
}

nonisolated struct SoraTerminalSummary: Codable, Equatable {
    var id: UUID
    var projectID: UUID
    var name: String
    var directory: String
    var exited: Bool
}

nonisolated struct SoraAutomationFailure: Error, Codable, Equatable {
    enum Code: String, Codable {
        case automationDisabled
        case invalidRequest
        case invalidPath
        case projectNotFound
        case terminalNotFound
        case terminalExited
        case noWindow
        case outputUnavailable
        case internalError
    }

    var code: Code
    var message: String
}
