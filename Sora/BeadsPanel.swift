import AppKit
import SwiftUI

enum BeadsFilter: String, CaseIterable, Identifiable {
    case ready = "Ready"
    case open = "Open"
    case inProgress = "In Progress"
    case blocked = "Blocked"
    case closed = "Closed"
    var id: Self { self }
}

struct BeadsPanel: View {
    @ObservedObject var model: BeadsModel
    let session: TerminalSession?
    @ObservedObject private var settings = AppSettings.shared
    @State private var filter = BeadsFilter.ready

    private var filteredIssues: [BeadsIssue] {
        model.issues.filter { issue in
            switch filter {
            case .ready: model.readyIDs.contains(issue.id)
            case .open: issue.status == "open"
            case .inProgress: issue.status == "in_progress"
            case .blocked: model.blockedIDs.contains(issue.id) || issue.isBlocked || issue.status == "blocked"
            case .closed: issue.status == "closed"
            }
        }.sorted { ($0.priority, $0.id) < ($1.priority, $1.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let error = model.error {
                failure(error)
            } else if !model.hasResolved {
                loading("Finding Beads workspace…")
            } else if model.workspacePath == nil {
                placeholder("No Beads workspace for this project", icon: "circle.grid.cross")
            } else if let detail = model.detail {
                issueDetail(detail)
            } else {
                issueList
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            if model.detail != nil {
                Button { model.clearDetail() } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help("Back to Issues")
                .accessibilityLabel("Back to issues")
            }
            Image(systemName: "circle.grid.cross")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(nsColor: Theme.accent))
            VStack(alignment: .leading, spacing: 1) {
                Text(model.detail?.id ?? "Beads")
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                Text(model.workspacePath ?? model.rootPath)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
            if model.isRefreshing || model.isLoadingDetail || model.isBusy {
                ProgressView().controlSize(.small).scaleEffect(0.6).frame(width: 12, height: 12)
                    .accessibilityLabel("Refreshing Beads")
            }
            Button { model.refresh(executablePath: settings.beadsExecutable) } label: {
                Image(systemName: "arrow.clockwise").frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .disabled(model.isRefreshing || model.isBusy)
            .help("Refresh Beads")
            .accessibilityLabel("Refresh Beads")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var issueList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Picker("Issue filter", selection: $filter) {
                    ForEach(BeadsFilter.allCases) { filter in Text(filter.rawValue).tag(filter) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                Spacer()
                Text("\(filteredIssues.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("\(filteredIssues.count) issues")
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 6)

            if filteredIssues.isEmpty {
                placeholder("No \(filter.rawValue.lowercased()) issues", icon: "checkmark.circle")
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredIssues) { issue in
                            Button {
                                model.loadDetail(id: issue.id, executablePath: settings.beadsExecutable)
                            } label: { issueRow(issue) }
                            .buttonStyle(.plain)
                            .contextMenu { issueMenu(issue) }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private func issueRow(_ issue: BeadsIssue) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Text("P\(issue.priority)")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                Text(issue.issueType.uppercased())
                    .font(.system(size: 8.5, weight: .medium))
                Spacer()
                Text(issue.id)
                    .font(.system(size: 9, design: .monospaced))
            }
            .foregroundStyle(.tertiary)
            Text(issue.title)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4) {
                Image(systemName: statusIcon(issue))
                    .accessibilityHidden(true)
                Text(statusLabel(issue))
                if let assignee = issue.assignee {
                    Text("· \(assignee)").lineLimit(1)
                }
            }
            .font(.system(size: 9.5))
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.045)))
        .contentShape(RoundedRectangle(cornerRadius: 5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(issue.id), priority \(issue.priority), \(issue.issueType), \(statusLabel(issue)), \(issue.title)")
    }

    private func issueDetail(_ issue: BeadsIssue) -> some View {
        VStack(spacing: 0) {
            if let result = model.operationResult {
                HStack {
                    Image(systemName: "checkmark.circle")
                    Text(result).lineLimit(1)
                    Spacer()
                    Button { model.dismissOperation() } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain).accessibilityLabel("Dismiss result")
                }
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.primary.opacity(0.04))
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(issue.title)
                        .font(.system(size: 14, weight: .semibold))
                        .textSelection(.enabled)
                    HStack(spacing: 5) {
                        badge("P\(issue.priority)")
                        badge(issue.issueType)
                        badge(statusLabel(issue))
                    }
                    optionalSection("Description", issue.description)
                    optionalSection("Design", issue.design)
                    optionalSection("Acceptance Criteria", issue.acceptanceCriteria)
                    if !issue.labels.isEmpty { optionalSection("Labels", issue.labels.joined(separator: ", ")) }
                    if let assignee = issue.assignee { optionalSection("Assignee", assignee) }
                    optionalSection("Parent", issue.parent)
                    relations("Children", issue.dependents.filter { $0.dependencyType == "parent-child" })
                    relations("Depends on", issue.dependencies.filter { $0.dependencyType != "parent-child" })
                    relations("Dependents", issue.dependents.filter { $0.dependencyType != "parent-child" })
                    if !issue.comments.isEmpty {
                        sectionTitle("Comments")
                        ForEach(Array(issue.comments.enumerated()), id: \.offset) { _, comment in
                            VStack(alignment: .leading, spacing: 3) {
                                if let author = comment.author { Text(author).font(.system(size: 10, weight: .medium)) }
                                Text(comment.text).font(.system(size: 11)).textSelection(.enabled)
                            }
                            .padding(7)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.04)))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
            actionBar(issue)
        }
    }

    private func actionBar(_ issue: BeadsIssue) -> some View {
        HStack(spacing: 5) {
            if model.readyIDs.contains(issue.id) {
                actionButton("Claim", icon: "person.badge.plus", disabled: model.isBusy) {
                    model.claim(issue, executablePath: settings.beadsExecutable)
                }
            }
            if issue.status == "closed" {
                actionButton("Reopen", icon: "arrow.uturn.backward", disabled: model.isBusy) {
                    model.reopen(issue, executablePath: settings.beadsExecutable)
                }
            } else {
                actionButton("Close", icon: "checkmark", disabled: model.isBusy) {
                    model.close(issue, executablePath: settings.beadsExecutable)
                }
            }
            Spacer(minLength: 0)
            Menu {
                issueMenu(issue)
            } label: {
                Image(systemName: "ellipsis").frame(width: 24, height: 24)
            }
            .menuStyle(.button).menuIndicator(.hidden).fixedSize()
            .help("More Issue Actions")
            .accessibilityLabel("More issue actions")
        }
        .padding(8)
        .overlay(alignment: .top) { Rectangle().fill(Color(nsColor: Theme.divider)).frame(height: 1) }
    }

    @ViewBuilder private func issueMenu(_ issue: BeadsIssue) -> some View {
        Button("Copy Issue ID") { copy(issue.id) }
        Button("Copy Issue as Context") { copy(context(for: issue)) }
        Divider()
        Button("Show in Active Terminal") { showInTerminal(issue) }
            .disabled(session == nil)
    }

    private func actionButton(_ title: String, icon: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 10.5, weight: .medium))
                .padding(.horizontal, 7).frame(height: 24)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.07)))
        }
        .buttonStyle(.plain).disabled(disabled)
    }

    @ViewBuilder private func optionalSection(_ title: String, _ text: String?) -> some View {
        if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                sectionTitle(title)
                Text(text).font(.system(size: 11)).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
    }

    @ViewBuilder private func relations(_ title: String, _ relations: [BeadsRelation]) -> some View {
        if !relations.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                sectionTitle(title)
                ForEach(relations) { relation in
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Image(systemName: relation.status == "closed" ? "checkmark.circle" : "circle")
                        Text(relation.id).font(.system(size: 10, design: .monospaced))
                        if let title = relation.title { Text(title).lineLimit(2) }
                    }
                    .font(.system(size: 10.5)).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased()).font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.tertiary)
    }

    private func badge(_ text: String) -> some View {
        Text(text).font(.system(size: 9.5, weight: .medium)).foregroundStyle(.secondary)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Capsule().fill(Color.primary.opacity(0.07)))
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: 10) {
            placeholder(message, icon: "exclamationmark.triangle")
            Button("Try Again") { model.refresh(executablePath: settings.beadsExecutable) }
        }
    }

    private func loading(_ text: String) -> some View {
        VStack(spacing: 8) { ProgressView().controlSize(.small); Text(text).font(.system(size: 11)).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func placeholder(_ text: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 22, weight: .light)).foregroundStyle(.tertiary)
            Text(text).font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(20).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func statusLabel(_ issue: BeadsIssue) -> String {
        if model.readyIDs.contains(issue.id) { return "Ready" }
        if model.blockedIDs.contains(issue.id) || issue.isBlocked { return "Blocked" }
        return issue.status.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func statusIcon(_ issue: BeadsIssue) -> String {
        if issue.status == "closed" { return "checkmark.circle" }
        if model.blockedIDs.contains(issue.id) || issue.isBlocked { return "exclamationmark.octagon" }
        if issue.status == "in_progress" { return "clock" }
        return "circle"
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func context(for issue: BeadsIssue) -> String {
        var lines = ["# \(issue.id): \(issue.title)", "Status: \(statusLabel(issue)) · Priority: P\(issue.priority) · Type: \(issue.issueType)"]
        if let description = issue.description, !description.isEmpty { lines += ["", description] }
        if let design = issue.design, !design.isEmpty { lines += ["", "## Design", design] }
        if let acceptance = issue.acceptanceCriteria, !acceptance.isEmpty { lines += ["", "## Acceptance Criteria", acceptance] }
        return lines.joined(separator: "\n")
    }

    private func showInTerminal(_ issue: BeadsIssue) {
        guard let session else { return }
        let path = BeadsCommand.executable(configuredPath: settings.beadsExecutable) ?? "bd"
        session.sendCommand("\(shellQuoted(path)) -C \(shellQuoted(model.rootPath)) show \(shellQuoted(issue.id))\r")
    }

    private func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
