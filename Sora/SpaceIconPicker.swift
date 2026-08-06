//
//  SpaceIconPicker.swift
//  sora
//

import SwiftUI

enum SpaceIconValue {
    static let symbolPrefix = "sf:"

    static func symbol(_ name: String) -> String {
        symbolPrefix + name
    }

    static func symbolName(in value: String) -> String? {
        guard value.hasPrefix(symbolPrefix) else { return nil }
        return String(value.dropFirst(symbolPrefix.count))
    }
}

struct SpaceIconGlyph: View {
    let value: String
    var size: CGFloat = 13

    var body: some View {
        if let symbol = SpaceIconValue.symbolName(in: value) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
        } else {
            Text(value)
                .font(.system(size: size))
        }
    }
}

struct SpaceIconPicker: View {
    @Binding var selection: String
    let onSelect: (String?) -> Void

    @State private var mode: Mode

    private enum Mode: String, CaseIterable, Identifiable {
        case emoji = "Emoji"
        case icon = "Icon"
        var id: Self { self }
    }

    private let columns = Array(repeating: GridItem(.fixed(30), spacing: 8), count: 8)

    private let symbols = [
        "star.fill", "bookmark.fill", "heart.fill", "flag.fill", "bolt.fill", "triangle.fill", "asterisk", "bell.fill",
        "square.on.square", "books.vertical.fill", "checkmark.square.fill", "person.crop.square", "square.3.layers.3d", "circle.grid.3x3.fill", "circle.grid.2x2.fill", "tag.fill",
        "folder.fill", "tray.fill", "clipboard.fill", "checkmark.circle.fill", "person.2.fill", "calendar.badge.checkmark", "message.fill", "text.bubble.fill",
        "textformat", "text.alignleft", "list.bullet", "checklist", "quote.opening", "magnifyingglass", "doc.text.fill", "graduationcap.fill",
        "sparkles", "paintbrush.fill", "lightbulb.fill", "music.note", "at", "bubble.left.fill", "sunrise.fill", "terminal.fill",
        "hammer.fill", "wrench.fill", "shippingbox.fill", "globe", "lock.fill", "key.fill", "leaf.fill", "flame.fill"
    ]

    private let emoji = [
        "🚀", "✨", "🔥", "⚡️", "💡", "🎯", "🧭", "🛠️",
        "💻", "🧪", "🧩", "📦", "📝", "📚", "🔐", "🔧",
        "🌱", "🌎", "☁️", "🌙", "☀️", "⭐️", "❤️", "💎",
        "🎨", "🎵", "📷", "🎮", "🤖", "👾", "🐛", "🦊",
        "🐙", "🦄", "🐝", "🍀", "🌊", "🏔️", "🏠", "🙌"
    ]

    init(selection: Binding<String>, onSelect: @escaping (String?) -> Void) {
        _selection = selection
        self.onSelect = onSelect
        _mode = State(initialValue: SpaceIconValue.symbolName(in: selection.wrappedValue) == nil && !selection.wrappedValue.isEmpty ? .emoji : .icon)
    }

    var body: some View {
        VStack(spacing: 14) {
            Picker("Icon type", selection: $mode) {
                ForEach(Mode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 212)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(mode == .icon ? symbols : emoji, id: \.self) { value in
                    let storedValue = mode == .icon ? SpaceIconValue.symbol(value) : value
                    Button {
                        selection = storedValue
                        onSelect(storedValue)
                    } label: {
                        SpaceIconGlyph(value: storedValue, size: mode == .icon ? 15 : 17)
                            .frame(width: 30, height: 30)
                            .background {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(selection == storedValue ? Color.primary.opacity(0.12) : .clear)
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mode == .icon ? value : "Emoji \(value)")
                }
            }

            if !selection.isEmpty {
                Button("Remove Icon", role: .destructive) {
                    selection = ""
                    onSelect(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 338)
    }
}
