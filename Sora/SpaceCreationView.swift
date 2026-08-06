//
//  SpaceCreationView.swift
//  sora
//

import AppKit
import SwiftUI

/// A focused creation moment: name the goal, attach the repositories that
/// serve it, then begin with one stable terminal tab per repository.
struct SpaceCreationView: View {
    @ObservedObject var manager: TerminalManager

    @State private var name = ""
    @State private var icon = ""
    @State private var isIconPickerPresented = false
    @State private var isIconButtonHovering = false
    @State private var repositories: [String] = []
    @State private var repositoryError: String?
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Button {
                    isIconPickerPresented = true
                } label: {
                    Group {
                        if icon.isEmpty {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(isIconButtonHovering ? .primary : .secondary)
                        } else {
                            SpaceIconGlyph(value: icon, size: 22)
                        }
                    }
                    .frame(width: 48, height: 48)
                    .background(Color.primary.opacity(isIconButtonHovering ? 0.1 : 0.06), in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.primary.opacity(0.1))
                    }
                }
                .buttonStyle(.plain)
                .onHover { isIconButtonHovering = $0 }
                .help("Choose Space Icon")
                .accessibilityLabel("Choose Space icon")
                .popover(isPresented: $isIconPickerPresented, arrowEdge: .top) {
                    SpaceIconPicker(selection: $icon) { value in
                        icon = value ?? ""
                        isIconPickerPresented = false
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Create a Space")
                        .font(.system(size: 22, weight: .semibold))
                    Text("Keep terminals, files, and folders for one goal together.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("SPACE NAME")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("e.g. Ship authentication", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFocused)
                    .onSubmit(create)
                    .accessibilityLabel("Space name")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("FOLDERS · OPTIONAL")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !repositories.isEmpty {
                        Button("Add Folders…", action: chooseRepositories)
                            .buttonStyle(.link)
                    }
                }

                if repositories.isEmpty {
                    Button(action: chooseRepositories) {
                        HStack(spacing: 9) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 15, weight: .medium))
                            Text("Add folders")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background {
                        RoundedRectangle(cornerRadius: 9)
                            .strokeBorder(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [4]))
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(repositories, id: \.self) { repository in
                            repositoryRow(repository)
                            if repository != repositories.last { Divider() }
                        }
                    }
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
                }

                if let repositoryError {
                    Text(repositoryError)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                } else {
                    Text("Each selected folder starts as a pinned terminal.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button("Cancel") { manager.isSpaceCreatorPresented = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create Space", action: create)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedName.isEmpty)
            }
        }
        .padding(22)
        .frame(width: 470)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.12))
        }
        .shadow(color: .black.opacity(0.35), radius: 28, y: 12)
        .onAppear { nameFocused = true }
    }

    private func repositoryRow(_ repository: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill")
                .foregroundStyle(Color(nsColor: Theme.accent))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(URL(fileURLWithPath: repository).lastPathComponent)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                Text((repository as NSString).deletingLastPathComponent)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer()
            Button {
                repositories.removeAll { $0 == repository }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Remove repository")
            .accessibilityLabel("Remove \(URL(fileURLWithPath: repository).lastPathComponent)")
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func chooseRepositories() {
        guard let window = NSApp.keyWindow else {
            repositoryError = "The repository picker could not find this window."
            return
        }
        RepositoryPicker.shared.present(for: window) { urls in
            addRepositories(urls)
        }
    }

    private func addRepositories(_ urls: [URL]) {
        for path in urls.map({ $0.standardizedFileURL.path }) where !repositories.contains(path) {
            repositories.append(path)
        }
        if trimmedName.isEmpty, repositories.count == 1 {
            name = URL(fileURLWithPath: repositories[0]).lastPathComponent
        }
        repositoryError = nil
    }

    private func create() {
        guard !trimmedName.isEmpty else {
            nameFocused = true
            return
        }
        manager.createSpace(
            name: trimmedName,
            icon: icon.isEmpty ? nil : icon,
            repositories: repositories
        )
        manager.isSpaceCreatorPresented = false
    }
}

@MainActor
final class RepositoryPicker {
    static let shared = RepositoryPicker()

    private let panel: NSOpenPanel
    private var isPresenting = false

    private init() {
        // Late NSOpenPanel initialization hangs in ViewBridge after terminal
        // processes start, so establish the native panel service at launch.
        panel = NSOpenPanel()
        panel.title = "Add Folders to Space"
        panel.message = "Choose one or more folders for this Space."
        panel.prompt = "Add"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = true
    }

    func present(for window: NSWindow, onSelection: @escaping ([URL]) -> Void) {
        guard !isPresenting else { return }
        isPresenting = true
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { [weak self, panel] in
            guard let self else { return }
            panel.beginSheetModal(for: window) { [weak self, panel] response in
                let urls = panel.urls
                self?.isPresenting = false
                if response == .OK {
                    onSelection(urls)
                }
            }
            panel.orderFrontRegardless()
        }
    }
}
