//
//  SyntaxHighlighting.swift
//  sora
//

import AppKit
import STPluginNeon
// TreeSitterResource defines TreeSitterLanguage. It's an internal module of the
// plugin package (not re-exported by STPluginNeon), but it must be imported
// directly: this toolchain enforces MemberImportVisibility, so an enum case is
// only usable when its defining module is imported.
import TreeSitterResource
// Base query files, for languages whose highlights inherit another language's
// (see `highlightsData(for:)`).
import TreeSitterCQueries
import TreeSitterJavaScriptQueries
import TreeSitterTypeScriptQueries
// Injection query files, for languages that embed other languages (see
// `injectionsData(for:)`). Like the base-query modules above, these are
// internal plugin targets imported directly for MemberImportVisibility.
import TreeSitterHTMLQueries
import TreeSitterMarkdownQueries
import TreeSitterPHPQueries
import TreeSitterRustQueries
// The one grammar sora vendors itself, for `SyntaxLanguage.tsx`.
import TreeSitterTSX

/// A grammar sora can highlight with: one of the plugin's bundled languages,
/// or TSX, which sora vendors.
///
/// TSX can't just be another `TreeSitterLanguage` case. tree-sitter-typescript
/// ships JSX as a **separate grammar** — `<tag>` is ambiguous with TypeScript's
/// `<T>x` type assertion, so no single parser does both — and the plugin builds
/// only the `typescript` half (its `TreeSitterTSX` target isn't part of any
/// product, so nothing in the package graph reaches it). Parsing a `.tsx` file
/// with the `typescript` grammar makes every element a parse error, which is
/// why the JSX in one used to render as one long unbroken string. See
/// `Vendor/TreeSitterTSX`.
enum SyntaxLanguage: Hashable {
    case bundled(TreeSitterLanguage)
    case tsx

    /// The tree-sitter grammar, as `TreeSitterLanguage.parser` hands it over.
    var parser: OpaquePointer {
        switch self {
        case .bundled(let language): language.parser
        case .tsx: tree_sitter_tsx()
        }
    }
}

/// Tree-sitter syntax highlighting for the source editor. `SourceTextEditor`
/// asks for a plugin per file; unsupported file types get `nil` and render as
/// plain text. The highlighter itself lives in `SyntaxHighlightPlugin`.
enum SyntaxHighlighting {
    /// Syntax colors follow the selected terminal theme's ANSI palette instead
    /// of imposing a separate neon palette. This keeps highlighting restrained
    /// and legible while preserving each user's chosen theme identity.
    ///
    /// The empty font table is deliberate: tokens keep the editor font and only
    /// receive color. `STPluginNeonAppKit.Theme` is qualified because sora has
    /// its own `Theme` in this module.
    @MainActor
    static let theme = STPluginNeonAppKit.Theme(
        colors: STPluginNeonAppKit.Theme.Colors(colors: [
            "plain": syntaxColor(),
            "boolean": syntaxColor(4),
            "comment": syntaxColor(8, fallbackElevation: 0.45),
            "constructor": syntaxColor(3),
            "function.call": syntaxColor(4),
            "include": syntaxColor(5),
            "keyword": syntaxColor(5),
            "keyword.function": syntaxColor(5),
            "keyword.return": syntaxColor(5),
            "method": syntaxColor(4),
            "number": syntaxColor(6),
            "operator": syntaxColor(5),
            "parameter": syntaxColor(),
            "punctuation.special": syntaxColor(),
            "string": syntaxColor(2),
            "text.literal": syntaxColor(2),
            "text.title": syntaxColor(4),
            "type": syntaxColor(3),
            "variable.builtin": syntaxColor(1),
            "variable": syntaxColor(),
        ]),
        fonts: STPluginNeonAppKit.Theme.Fonts(fonts: [:])
    )

    private nonisolated static func syntaxColor(
        _ paletteIndex: Int? = nil,
        fallbackElevation: CGFloat? = nil
    ) -> NSColor {
        NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let theme = Theme.terminal(dark: dark)
            if let paletteIndex, let color = theme.paletteNSColor(at: paletteIndex) {
                return color
            }
            if let fallbackElevation {
                return theme.surfaceNSColor(elevation: fallbackElevation)
            }
            return theme.foregroundNSColor
        }
    }

    /// A syntax-highlighting plugin for `path`, or `nil` when the file type has
    /// no bundled grammar (the editor then shows plain text).
    @MainActor
    static func plugin(for path: String) -> SyntaxHighlightPlugin? {
        guard let language = language(for: path) else { return nil }
        return SyntaxHighlightPlugin(
            theme: theme,
            language: language,
            highlightsData: highlightsData(for: language),
            injectionsData: injectionsData(for: language)
        )
    }

    /// The combined highlights query for a language: the query files it
    /// *inherits* (nvim-treesitter's `; inherits:` convention) concatenated
    /// ahead of its own, so the language-specific captures win. SwiftTreeSitter
    /// doesn't resolve inheritance, so without this TypeScript (inherits
    /// JavaScript) and C++ (inherits C) lose comments, strings and base
    /// keywords — everything defined only in the parent's query.
    ///
    /// JSX is the one addition that goes *last* rather than first: its
    /// `@tag`/`@attribute` captures have to beat the generic `(identifier)`
    /// rules both parents apply to the same node, so that `<main>` and `<Foo>`
    /// come out looking alike.
    static func highlightsData(for language: SyntaxLanguage) -> Data {
        var urls: [URL] = []
        switch language {
        case .tsx:
            // TSX inherits *both* parents. It contributes no query of its own:
            // tree-sitter-typescript's tsx and typescript highlights are the
            // same file, and only TypeScript's is built into the plugin.
            urls = [
                TreeSitterJavaScriptQueries.Query.highlightsFileURL,
                TreeSitterTypeScriptQueries.Query.highlightsFileURL,
                TreeSitterJavaScriptQueries.Query.highlightsJSXFileURL,
            ]
        case .bundled(let language):
            switch language {
            case .typescript:
                urls.append(TreeSitterJavaScriptQueries.Query.highlightsFileURL)
            case .cpp:
                urls.append(TreeSitterCQueries.Query.highlightsFileURL)
            default:
                break
            }
            if let own = language.highlightQueryURL {
                urls.append(own)
            }
            // The JavaScript grammar parses JSX too (`.jsx`, and `.js` in
            // practice), but keeps its element captures in a second file.
            if language == .javascript {
                urls.append(TreeSitterJavaScriptQueries.Query.highlightsJSXFileURL)
            }
        }

        var data = Data()
        for url in urls {
            guard let chunk = try? Data(contentsOf: url) else { continue }
            data.append(chunk)
            data.append(0x0A) // keep concatenated query files on separate lines
        }
        return data
    }

    /// The injections query for a language that embeds *other* languages — e.g.
    /// markdown fenced code blocks (` ```sh `), HTML `<script>`/`<style>`, PHP's
    /// interleaved HTML, Rust macro bodies — or `nil` for a self-contained
    /// language. When non-nil, `SyntaxHighlightCoordinator` sub-parses each
    /// embedded region with its own grammar so, say, a shell block's comments
    /// get the comment color instead of rendering as plain text.
    ///
    /// The single `.scm` isn't inheritance-merged (unlike `highlightsData`):
    /// injection queries don't use nvim's `; inherits:` convention.
    static func injectionsData(for language: SyntaxLanguage) -> Data? {
        let url: URL
        switch language {
        case .bundled(.markdown): url = TreeSitterMarkdownQueries.Query.injectionsFileURL
        case .bundled(.html):     url = TreeSitterHTMLQueries.Query.injectionsFileURL
        case .bundled(.php):      url = TreeSitterPHPQueries.Query.injectionsFileURL
        case .bundled(.rust):     url = TreeSitterRustQueries.Query.injectionsFileURL
        default:                  return nil
        }
        return try? Data(contentsOf: url)
    }

    /// The tree-sitter language named by an injection's `@injection.language`
    /// capture — the info string after a code fence (` ```bash `), or a name a
    /// grammar hard-codes (HTML injects `"javascript"`/`"css"`). Resolved
    /// against a small alias table and then the file-extension map, since fence
    /// info strings are usually just extensions (`sh`, `js`, `py`). Names with
    /// no bundled grammar (`text`, `diff`, `markdown_inline`, …) return `nil`
    /// and that region is left as plain text.
    static func language(forInjectionName name: String) -> SyntaxLanguage? {
        let key = name.lowercased()
        if key == tsxExtension || key == "typescriptreact" { return .tsx }
        if let language = injectionAliases[key] { return .bundled(language) }
        return byExtension[key].map(SyntaxLanguage.bundled)
    }

    /// Long-form injection names not already covered by `byExtension` (which
    /// handles `sh`, `js`, `ts`, `py`, `rb`, `rs`, `cpp`, `c++`, `yml`, …).
    private static let injectionAliases: [String: TreeSitterLanguage] = [
        "shell": .bash, "shellscript": .bash, "shell-script": .bash,
        "javascript": .javascript, "node": .javascript, "javascriptreact": .javascript,
        "typescript": .typescript,
        "python": .python,
        "ruby": .ruby,
        "rust": .rust,
        "golang": .go,
        "cplusplus": .cpp,
        "csharp": .csharp, "c#": .csharp,
        "markdown": .markdown,
    ]

    /// The tree-sitter language for a file, matched by extension first and
    /// then by a few well-known extensionless names.
    static func language(for path: String) -> SyntaxLanguage? {
        let name = (path as NSString).lastPathComponent.lowercased()
        let ext = (name as NSString).pathExtension
        // Kept out of `byExtension`, which only holds the plugin's grammars.
        if ext == tsxExtension { return .tsx }
        if let language = byExtension[ext] {
            return .bundled(language)
        }
        return byName[name].map(SyntaxLanguage.bundled)
    }

    /// The one extension that needs the vendored grammar. `.mts`/`.cts` stay on
    /// plain TypeScript — only `.tsx` may contain JSX.
    private static let tsxExtension = "tsx"

    private static let byExtension: [String: TreeSitterLanguage] = [
        "swift": .swift,
        "js": .javascript, "mjs": .javascript, "cjs": .javascript, "jsx": .javascript,
        "ts": .typescript, "mts": .typescript, "cts": .typescript,
        "json": .json, "jsonc": .json, "json5": .json,
        "py": .python, "pyi": .python, "pyw": .python,
        "rb": .ruby, "rake": .ruby, "gemspec": .ruby,
        "rs": .rust,
        "go": .go,
        "c": .c, "h": .c,
        "cc": .cpp, "cpp": .cpp, "cxx": .cpp, "c++": .cpp,
        "hpp": .cpp, "hh": .cpp, "hxx": .cpp, "h++": .cpp,
        "cs": .csharp,
        "css": .css, "less": .css, "scss": .css,
        "html": .html, "htm": .html, "xhtml": .html, "svelte": .html, "vue": .html,
        "java": .java,
        "php": .php, "phtml": .php,
        "sh": .bash, "bash": .bash, "zsh": .bash, "ksh": .bash,
        "sql": .sql,
        "toml": .toml,
        "yaml": .yaml, "yml": .yaml,
        "md": .markdown, "markdown": .markdown, "mdown": .markdown, "mkd": .markdown, "mdx": .markdown,
    ]

    private static let byName: [String: TreeSitterLanguage] = [
        ".bashrc": .bash, ".bash_profile": .bash, ".profile": .bash,
        ".zshrc": .bash, ".zprofile": .bash, ".zshenv": .bash,
        "gemfile": .ruby, "rakefile": .ruby, "podfile": .ruby, "brewfile": .ruby,
    ]
}
