import AppKit

// MARK: - Token Kind

/// Semantic category for a syntax token.
enum SyntaxTokenKind: Hashable {
    case keyword
    case string
    case comment
    case number
    case typeIdentifier
    case functionCall
    case preprocessor
    case xmlTag
    case attribute
    case htmlEntity
}

// MARK: - Language

/// Source-code language used to select the correct token pattern set.
enum SyntaxLanguage {
    case swift
    case typeScript   // tsx, ts, jsx, js
    case python
    case ruby
    case go
    case rust
    case java
    case kotlin
    case css
    case html
    case json
    case yaml
    case toml
    case shell
    case cOrCpp
    case sql
    case markdown
    case plainText

    // swiftlint:disable:next cyclomatic_complexity
    static func from(filename: String) -> SyntaxLanguage {
        let lower = filename.lowercased()
        let ext = (lower as NSString).pathExtension

        // Exact filename matches first
        switch lower {
        case "dockerfile", "dockerfile.dev", "dockerfile.prod", "dockerfile.staging",
             "makefile", "rakefile", "gemfile", "podfile":
            return .shell
        case "package.json", "tsconfig.json", "jsconfig.json", ".eslintrc.json",
             "bun.lockb":
            return .json
        case "docker-compose.yml", "docker-compose.yaml":
            return .yaml
        default:
            break
        }

        switch ext {
        case "swift":         return .swift
        case "ts", "tsx", "js", "jsx", "mjs", "cjs": return .typeScript
        case "py", "pyi":     return .python
        case "rb", "rake", "gemspec": return .ruby
        case "go":            return .go
        case "rs":            return .rust
        case "java":          return .java
        case "kt", "kts":     return .kotlin
        case "css", "scss", "sass", "less": return .css
        case "html", "htm", "xhtml", "svelte", "vue": return .html
        case "json":          return .json
        case "yaml", "yml":   return .yaml
        case "toml":          return .toml
        case "sh", "bash", "zsh", "fish", "command": return .shell
        case "c", "cc", "cpp", "cxx", "h", "hpp", "hh", "m", "mm": return .cOrCpp
        case "sql":           return .sql
        case "md", "mdx", "markdown": return .markdown
        default:              return .plainText
        }
    }
}

// MARK: - Token Pattern

private struct TokenPattern {
    let kind: SyntaxTokenKind
    let regex: NSRegularExpression

    init(kind: SyntaxTokenKind, pattern: String, options: NSRegularExpression.Options = []) {
        // Patterns that fail to compile should crash early in development.
        self.kind = kind
        // swiftlint:disable:next force_try
        self.regex = try! NSRegularExpression(pattern: pattern, options: options)
    }
}

// MARK: - Color Scheme Support

private extension NSColor {
    /// Whether this color is considered "light" (luminance > 0.5 in the display color space).
    var isLight: Bool {
        guard let rgb = usingColorSpace(.sRGB) else { return true }
        let r = rgb.redComponent, g = rgb.greenComponent, b = rgb.blueComponent
        let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return lum > 0.5
    }
}

// MARK: - Theme Colors

/// Adaptive syntax colors for light and dark backgrounds.
private struct SyntaxTheme {
    let keyword:      NSColor
    let string:       NSColor
    let comment:      NSColor
    let number:       NSColor
    let typeIdent:    NSColor
    let functionCall: NSColor
    let preprocessor: NSColor
    let xmlTag:       NSColor
    let attribute:    NSColor
    let htmlEntity:   NSColor

    static func make(forDark isDark: Bool) -> SyntaxTheme {
        if isDark {
            return SyntaxTheme(
                keyword:      NSColor(red: 0.99, green: 0.45, blue: 0.44, alpha: 1), // pink-red
                string:       NSColor(red: 0.70, green: 0.93, blue: 0.60, alpha: 1), // green
                comment:      NSColor(red: 0.48, green: 0.55, blue: 0.48, alpha: 1), // dim green-gray
                number:       NSColor(red: 0.82, green: 0.70, blue: 0.99, alpha: 1), // lavender
                typeIdent:    NSColor(red: 0.35, green: 0.85, blue: 0.95, alpha: 1), // cyan
                functionCall: NSColor(red: 0.99, green: 0.83, blue: 0.52, alpha: 1), // yellow
                preprocessor: NSColor(red: 0.99, green: 0.65, blue: 0.35, alpha: 1), // orange
                xmlTag:       NSColor(red: 0.38, green: 0.78, blue: 0.88, alpha: 1), // teal
                attribute:    NSColor(red: 0.70, green: 0.82, blue: 0.45, alpha: 1), // olive-green
                htmlEntity:   NSColor(red: 0.88, green: 0.57, blue: 0.40, alpha: 1)  // salmon
            )
        } else {
            return SyntaxTheme(
                keyword:      NSColor(red: 0.70, green: 0.10, blue: 0.45, alpha: 1), // magenta
                string:       NSColor(red: 0.17, green: 0.50, blue: 0.10, alpha: 1), // dark green
                comment:      NSColor(red: 0.40, green: 0.47, blue: 0.42, alpha: 1), // gray-green
                number:       NSColor(red: 0.38, green: 0.20, blue: 0.73, alpha: 1), // purple
                typeIdent:    NSColor(red: 0.10, green: 0.40, blue: 0.70, alpha: 1), // blue
                functionCall: NSColor(red: 0.60, green: 0.40, blue: 0.00, alpha: 1), // brown
                preprocessor: NSColor(red: 0.55, green: 0.25, blue: 0.00, alpha: 1), // dark orange
                xmlTag:       NSColor(red: 0.13, green: 0.45, blue: 0.60, alpha: 1), // teal
                attribute:    NSColor(red: 0.30, green: 0.50, blue: 0.10, alpha: 1), // olive
                htmlEntity:   NSColor(red: 0.65, green: 0.30, blue: 0.10, alpha: 1)  // burnt orange
            )
        }
    }

    func color(for kind: SyntaxTokenKind) -> NSColor {
        switch kind {
        case .keyword:      return keyword
        case .string:       return string
        case .comment:      return comment
        case .number:       return number
        case .typeIdentifier: return typeIdent
        case .functionCall: return functionCall
        case .preprocessor: return preprocessor
        case .xmlTag:       return xmlTag
        case .attribute:    return attribute
        case .htmlEntity:   return htmlEntity
        }
    }
}

// MARK: - Pattern Library

// swiftlint:disable:next type_body_length
private enum SyntaxPatternLibrary {

    // Common cross-language fragments
    private static let lineComment       = "//[^\\n]*"
    private static let blockComment      = "/\\*[\\s\\S]*?\\*/"
    private static let hashLineComment   = "#[^\\n]*"
    private static let doubleQuotedStr   = "\"(?:[^\"\\\\]|\\\\.)*\""
    private static let singleQuotedStr   = "'(?:[^'\\\\]|\\\\.)*'"
    private static let backtickStr       = "`(?:[^`\\\\]|\\\\.)*`"
    private static let tripleDoubleStr   = "\"\"\"[\\s\\S]*?\"\"\""
    private static let tripleSingleStr   = "'''[\\s\\S]*?'''"
    private static let numberLiteral     = "\\b(?:0[xXbBoO][0-9a-fA-F_]+|\\d+(?:[_\\d]*\\.\\d+)?(?:[eEpP][+-]?\\d+)?[a-zA-Z_]*|0\\.\\d+)\\b"

    static func patterns(for language: SyntaxLanguage) -> [TokenPattern] {
        switch language {
        case .swift:   return swiftPatterns()
        case .typeScript: return typeScriptPatterns()
        case .python:  return pythonPatterns()
        case .ruby:    return rubyPatterns()
        case .go:      return goPatterns()
        case .rust:    return rustPatterns()
        case .java:    return javaPatterns()
        case .kotlin:  return kotlinPatterns()
        case .css:     return cssPatterns()
        case .html:    return htmlPatterns()
        case .json:    return jsonPatterns()
        case .yaml:    return yamlPatterns()
        case .toml:    return tomlPatterns()
        case .shell:   return shellPatterns()
        case .cOrCpp:  return cPatterns()
        case .sql:     return sqlPatterns()
        case .markdown: return markdownPatterns()
        case .plainText: return []
        }
    }

    // MARK: Swift

    private static func swiftPatterns() -> [TokenPattern] {[
        TokenPattern(kind: .comment, pattern: blockComment),
        TokenPattern(kind: .comment, pattern: lineComment),
        TokenPattern(kind: .string,  pattern: tripleDoubleStr),
        TokenPattern(kind: .string,  pattern: doubleQuotedStr),
        TokenPattern(kind: .preprocessor, pattern: "^\\s*#(?:if|else|elseif|endif|available|unavailable|error|warning|sourceLocation|file|line|column|function|dsohandle|selector|keyPath|colorLiteral|imageLiteral|fileLiteral)\\b", options: [.anchorsMatchLines]),
        TokenPattern(kind: .keyword, pattern: #"\b(?:import|class|struct|enum|protocol|extension|actor|func|var|let|if|else|guard|switch|case|default|for|in|while|repeat|return|throw|throws|rethrows|try|catch|do|defer|break|continue|fallthrough|typealias|associatedtype|where|as|is|nil|true|false|self|Self|super|init|deinit|subscript|static|class|final|override|open|public|internal|fileprivate|private|mutating|nonmutating|lazy|weak|unowned|inout|optional|required|convenience|indirect|async|await|some|any|@escaping|@autoclosure|@discardableResult|@available|@objc|@objcMembers|@MainActor|@Published|@State|@Binding|@Environment|@EnvironmentObject|@ObservedObject|@StateObject|@ViewBuilder|@AppStorage|@SceneStorage|@Sendable|@testable)\b"#),
        TokenPattern(kind: .typeIdentifier, pattern: "\\b[A-Z][A-Za-z0-9_]*\\b"),
        TokenPattern(kind: .functionCall,   pattern: "\\b([a-z_][a-zA-Z0-9_]*)\\s*(?=\\()"),
        TokenPattern(kind: .number, pattern: numberLiteral),
    ]}

    // MARK: TypeScript / JavaScript

    private static func typeScriptPatterns() -> [TokenPattern] {[
        TokenPattern(kind: .comment, pattern: blockComment),
        TokenPattern(kind: .comment, pattern: lineComment),
        TokenPattern(kind: .string,  pattern: tripleDoubleStr),
        TokenPattern(kind: .string,  pattern: backtickStr),
        TokenPattern(kind: .string,  pattern: doubleQuotedStr),
        TokenPattern(kind: .string,  pattern: singleQuotedStr),
        TokenPattern(kind: .keyword, pattern: #"\b(?:import|export|from|default|class|interface|type|enum|namespace|module|declare|abstract|implements|extends|function|const|let|var|if|else|switch|case|break|return|throw|try|catch|finally|for|of|in|while|do|new|delete|typeof|instanceof|void|null|undefined|true|false|this|super|static|async|await|yield|get|set|as|keyof|readonly|public|private|protected|override|satisfies|infer|never|unknown|any)\b"#),
        TokenPattern(kind: .typeIdentifier, pattern: "\\b[A-Z][A-Za-z0-9_]*\\b"),
        TokenPattern(kind: .attribute,      pattern: "@[A-Za-z_][A-Za-z0-9_\\.]*"),
        TokenPattern(kind: .functionCall,   pattern: "\\b([a-z_][a-zA-Z0-9_]*)\\s*(?=\\()"),
        TokenPattern(kind: .number, pattern: numberLiteral),
    ]}

    // MARK: Python

    private static func pythonPatterns() -> [TokenPattern] {[
        TokenPattern(kind: .comment, pattern: hashLineComment),
        TokenPattern(kind: .string,  pattern: tripleSingleStr),
        TokenPattern(kind: .string,  pattern: tripleDoubleStr),
        TokenPattern(kind: .string,  pattern: doubleQuotedStr),
        TokenPattern(kind: .string,  pattern: singleQuotedStr),
        TokenPattern(kind: .preprocessor, pattern: "^from\\b|^import\\b", options: [.anchorsMatchLines]),
        TokenPattern(kind: .keyword, pattern: #"\b(?:and|as|assert|async|await|break|class|continue|def|del|elif|else|except|finally|for|from|global|if|import|in|is|lambda|nonlocal|not|or|pass|raise|return|try|while|with|yield|None|True|False|self|cls)\b"#),
        TokenPattern(kind: .typeIdentifier, pattern: "\\b[A-Z][A-Za-z0-9_]*\\b"),
        TokenPattern(kind: .attribute,      pattern: "@[A-Za-z_][A-Za-z0-9_\\.]*"),
        TokenPattern(kind: .functionCall,   pattern: "\\b([a-z_][a-zA-Z0-9_]*)\\s*(?=\\()"),
        TokenPattern(kind: .number, pattern: numberLiteral),
    ]}

    // MARK: Ruby

    private static func rubyPatterns() -> [TokenPattern] {[
        TokenPattern(kind: .comment, pattern: hashLineComment),
        TokenPattern(kind: .string,  pattern: doubleQuotedStr),
        TokenPattern(kind: .string,  pattern: singleQuotedStr),
        TokenPattern(kind: .keyword, pattern: #"\b(?:BEGIN|END|alias|and|begin|break|case|class|def|defined\?|do|else|elsif|end|ensure|false|for|if|in|module|next|nil|not|or|puts|raise|redo|require|rescue|retry|return|self|super|then|true|undef|unless|until|when|while|yield)\b"#),
        TokenPattern(kind: .typeIdentifier, pattern: "\\b[A-Z][A-Za-z0-9_]*\\b"),
        TokenPattern(kind: .number, pattern: numberLiteral),
    ]}

    // MARK: Go

    private static func goPatterns() -> [TokenPattern] {[
        TokenPattern(kind: .comment, pattern: blockComment),
        TokenPattern(kind: .comment, pattern: lineComment),
        TokenPattern(kind: .string,  pattern: backtickStr),
        TokenPattern(kind: .string,  pattern: doubleQuotedStr),
        TokenPattern(kind: .keyword, pattern: #"\b(?:break|case|chan|const|continue|default|defer|else|fallthrough|for|func|go|goto|if|import|interface|map|package|range|return|select|struct|switch|type|var|nil|true|false|iota|make|new|len|cap|append|copy|close|delete|panic|recover|print|println|error)\b"#),
        TokenPattern(kind: .typeIdentifier, pattern: "\\b[A-Z][A-Za-z0-9_]*\\b"),
        TokenPattern(kind: .functionCall,   pattern: "\\b([a-z_][a-zA-Z0-9_]*)\\s*(?=\\()"),
        TokenPattern(kind: .number, pattern: numberLiteral),
    ]}

    // MARK: Rust

    private static func rustPatterns() -> [TokenPattern] {[
        TokenPattern(kind: .comment, pattern: blockComment),
        TokenPattern(kind: .comment, pattern: lineComment),
        TokenPattern(kind: .string,  pattern: doubleQuotedStr),
        TokenPattern(kind: .preprocessor, pattern: "#\\[.*?\\]"),
        TokenPattern(kind: .keyword, pattern: #"\b(?:as|async|await|break|const|continue|crate|dyn|else|enum|extern|false|fn|for|if|impl|in|let|loop|match|mod|move|mut|pub|ref|return|self|Self|static|struct|super|trait|true|type|union|unsafe|use|where|while|abstract|become|box|do|final|macro|override|priv|try|typeof|unsized|virtual|yield)\b"#),
        TokenPattern(kind: .typeIdentifier, pattern: "\\b[A-Z][A-Za-z0-9_]*\\b"),
        TokenPattern(kind: .attribute,      pattern: "#!?\\["),
        TokenPattern(kind: .functionCall,   pattern: "\\b([a-z_][a-zA-Z0-9_]*)\\s*(?=\\()"),
        TokenPattern(kind: .number, pattern: numberLiteral),
    ]}

    // MARK: Java

    private static func javaPatterns() -> [TokenPattern] {[
        TokenPattern(kind: .comment, pattern: blockComment),
        TokenPattern(kind: .comment, pattern: lineComment),
        TokenPattern(kind: .string,  pattern: doubleQuotedStr),
        TokenPattern(kind: .keyword, pattern: #"\b(?:abstract|assert|boolean|break|byte|case|catch|char|class|const|continue|default|do|double|else|enum|extends|final|finally|float|for|goto|if|implements|import|instanceof|int|interface|long|native|new|package|private|protected|public|return|short|static|strictfp|super|switch|synchronized|this|throw|throws|transient|try|var|void|volatile|while|null|true|false|record|sealed|permits|yield)\b"#),
        TokenPattern(kind: .typeIdentifier, pattern: "\\b[A-Z][A-Za-z0-9_]*\\b"),
        TokenPattern(kind: .attribute,      pattern: "@[A-Za-z_][A-Za-z0-9_]*"),
        TokenPattern(kind: .number, pattern: numberLiteral),
    ]}

    // MARK: Kotlin

    private static func kotlinPatterns() -> [TokenPattern] {[
        TokenPattern(kind: .comment, pattern: blockComment),
        TokenPattern(kind: .comment, pattern: lineComment),
        TokenPattern(kind: .string,  pattern: tripleDoubleStr),
        TokenPattern(kind: .string,  pattern: doubleQuotedStr),
        TokenPattern(kind: .keyword, pattern: #"\b(?:abstract|actual|annotation|as|break|by|catch|class|companion|const|constructor|continue|crossinline|data|delegate|do|dynamic|else|enum|expect|external|false|field|file|final|finally|for|fun|get|if|import|in|infix|init|inline|inner|interface|internal|is|it|lateinit|noinline|null|object|open|operator|out|override|package|param|private|property|protected|public|receiver|reified|return|sealed|set|setparam|super|suspend|tailrec|this|throw|true|try|typealias|typeof|val|value|var|vararg|when|where|while)\b"#),
        TokenPattern(kind: .typeIdentifier, pattern: "\\b[A-Z][A-Za-z0-9_]*\\b"),
        TokenPattern(kind: .attribute,      pattern: "@[A-Za-z_][A-Za-z0-9_]*"),
        TokenPattern(kind: .functionCall,   pattern: "\\b([a-z_][a-zA-Z0-9_]*)\\s*(?=\\()"),
        TokenPattern(kind: .number, pattern: numberLiteral),
    ]}

    // MARK: CSS

    private static func cssPatterns() -> [TokenPattern] {[
        TokenPattern(kind: .comment, pattern: blockComment),
        TokenPattern(kind: .string,  pattern: doubleQuotedStr),
        TokenPattern(kind: .string,  pattern: singleQuotedStr),
        TokenPattern(kind: .keyword, pattern: #"@(?:import|media|keyframes|charset|font-face|supports|layer|property|namespace|page|counter-style|color-profile|document|viewport|-webkit-[a-z-]+)\b"#),
        TokenPattern(kind: .attribute,  pattern: ":[:-]?[a-zA-Z][a-zA-Z0-9_-]*(?=\\s*\\{|\\s*,|\\s*\\))"),
        TokenPattern(kind: .functionCall, pattern: "\\b[a-z-]+(?=\\()"),
        TokenPattern(kind: .number,  pattern: "-?\\b\\d*\\.?\\d+(?:%|px|em|rem|vh|vw|pt|pc|cm|mm|in|ex|ch|vmin|vmax|fr|deg|rad|turn|s|ms)?\\b"),
        TokenPattern(kind: .xmlTag,  pattern: "#[0-9a-fA-F]{3,8}\\b"),
    ]}

    // MARK: HTML

    private static func htmlPatterns() -> [TokenPattern] {[
        TokenPattern(kind: .comment,    pattern: "<!--[\\s\\S]*?-->"),
        TokenPattern(kind: .string,     pattern: doubleQuotedStr),
        TokenPattern(kind: .string,     pattern: singleQuotedStr),
        TokenPattern(kind: .xmlTag,     pattern: "</?[A-Za-z][A-Za-z0-9_:-]*"),
        TokenPattern(kind: .attribute,  pattern: "\\b[a-zA-Z][a-zA-Z0-9_:-]*(?=\\s*=)"),
        TokenPattern(kind: .htmlEntity, pattern: "&(?:[a-zA-Z]+|#\\d+|#x[0-9a-fA-F]+);"),
        TokenPattern(kind: .keyword,    pattern: ">"),
    ]}

    // MARK: JSON

    private static func jsonPatterns() -> [TokenPattern] {[
        TokenPattern(kind: .keyword,  pattern: "\\b(?:true|false|null)\\b"),
        TokenPattern(kind: .string,   pattern: doubleQuotedStr),
        TokenPattern(kind: .number,   pattern: "-?\\b\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?\\b"),
    ]}

    // MARK: YAML

    private static func yamlPatterns() -> [TokenPattern] {[
        TokenPattern(kind: .comment,    pattern: "#[^\\n]*"),
        TokenPattern(kind: .string,     pattern: doubleQuotedStr),
        TokenPattern(kind: .string,     pattern: singleQuotedStr),
        TokenPattern(kind: .keyword,    pattern: "\\b(?:true|false|null|yes|no|on|off)\\b"),
        TokenPattern(kind: .typeIdentifier, pattern: "^[\\w.-]+(?=:)", options: [.anchorsMatchLines]),
        TokenPattern(kind: .preprocessor, pattern: "^---$|^\\.\\.\\.\\.$", options: [.anchorsMatchLines]),
        TokenPattern(kind: .number,     pattern: "-?\\b\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?\\b"),
    ]}

    // MARK: TOML

    private static func tomlPatterns() -> [TokenPattern] {[
        TokenPattern(kind: .comment,    pattern: hashLineComment),
        TokenPattern(kind: .string,     pattern: tripleDoubleStr),
        TokenPattern(kind: .string,     pattern: doubleQuotedStr),
        TokenPattern(kind: .string,     pattern: singleQuotedStr),
        TokenPattern(kind: .keyword,    pattern: "\\b(?:true|false)\\b"),
        TokenPattern(kind: .typeIdentifier, pattern: "^\\[[^\\]]+\\]", options: [.anchorsMatchLines]),
        TokenPattern(kind: .functionCall, pattern: "^[\\w.-]+(?=\\s*=)", options: [.anchorsMatchLines]),
        TokenPattern(kind: .number,     pattern: "-?\\b\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?\\b"),
    ]}

    // MARK: Shell

    private static func shellPatterns() -> [TokenPattern] {[
        TokenPattern(kind: .comment,    pattern: hashLineComment),
        TokenPattern(kind: .string,     pattern: doubleQuotedStr),
        TokenPattern(kind: .string,     pattern: singleQuotedStr),
        TokenPattern(kind: .keyword,    pattern: #"\b(?:if|then|else|elif|fi|for|do|done|while|until|case|esac|in|function|return|exit|local|export|readonly|declare|typeset|set|unset|shift|source|echo|printf|read|test|trap|exec|eval|break|continue)\b"#),
        TokenPattern(kind: .preprocessor, pattern: "^#!.*$", options: [.anchorsMatchLines]),
        TokenPattern(kind: .attribute,  pattern: "\\$[A-Za-z_][A-Za-z0-9_]*|\\$\\{[^}]+\\}|\\$\\([^)]+\\)"),
        TokenPattern(kind: .number,     pattern: "\\b\\d+\\b"),
    ]}

    // MARK: C / C++

    private static func cPatterns() -> [TokenPattern] {[
        TokenPattern(kind: .comment, pattern: blockComment),
        TokenPattern(kind: .comment, pattern: lineComment),
        TokenPattern(kind: .string,  pattern: doubleQuotedStr),
        TokenPattern(kind: .preprocessor, pattern: "^\\s*#\\s*(?:include|define|undef|if|ifdef|ifndef|elif|else|endif|pragma|error|warning|line)\\b.*$", options: [.anchorsMatchLines]),
        TokenPattern(kind: .keyword, pattern: #"\b(?:auto|break|case|char|const|continue|default|do|double|else|enum|extern|float|for|goto|if|inline|int|long|register|restrict|return|short|signed|sizeof|static|struct|switch|typedef|union|unsigned|void|volatile|while|nullptr|true|false|class|template|typename|namespace|using|new|delete|operator|virtual|override|final|explicit|constexpr|consteval|constinit|noexcept|static_assert|decltype|auto|concept|requires|co_await|co_return|co_yield|export|import|module)\b"#),
        TokenPattern(kind: .typeIdentifier, pattern: "\\b[A-Z][A-Za-z0-9_]*\\b"),
        TokenPattern(kind: .number, pattern: numberLiteral),
    ]}

    // MARK: SQL

    private static func sqlPatterns() -> [TokenPattern] {[
        TokenPattern(kind: .comment, pattern: "--[^\\n]*"),
        TokenPattern(kind: .comment, pattern: blockComment),
        TokenPattern(kind: .string,  pattern: singleQuotedStr),
        TokenPattern(kind: .string,  pattern: "\"(?:[^\"\\\\]|\\\\.)*\""),
        TokenPattern(kind: .keyword, pattern: #"(?i)\b(?:SELECT|FROM|WHERE|JOIN|LEFT|RIGHT|INNER|OUTER|FULL|ON|AS|INSERT|INTO|VALUES|UPDATE|SET|DELETE|CREATE|TABLE|VIEW|INDEX|DROP|ALTER|ADD|COLUMN|PRIMARY|KEY|FOREIGN|REFERENCES|UNIQUE|NOT|NULL|DEFAULT|CHECK|AND|OR|IN|EXISTS|LIKE|BETWEEN|ORDER|BY|GROUP|HAVING|LIMIT|OFFSET|UNION|ALL|DISTINCT|CASE|WHEN|THEN|ELSE|END|OVER|PARTITION|WINDOW|WITH|RECURSIVE|TRUNCATE|ROLLBACK|COMMIT|TRANSACTION|BEGIN|EXPLAIN|ANALYZE)\b"#),
        TokenPattern(kind: .functionCall, pattern: #"(?i)\b(?:COUNT|SUM|AVG|MAX|MIN|COALESCE|NULLIF|CAST|CONVERT|IFNULL|NOW|DATE|YEAR|MONTH|DAY|LENGTH|SUBSTR|SUBSTRING|CONCAT|TRIM|UPPER|LOWER|ROUND|FLOOR|CEIL|ABS|MOD|ROW_NUMBER|RANK|DENSE_RANK|LAG|LEAD)\s*(?=\()"#),
        TokenPattern(kind: .number, pattern: "-?\\b\\d+(?:\\.\\d+)?\\b"),
    ]}

    // MARK: Markdown

    private static func markdownPatterns() -> [TokenPattern] {[
        TokenPattern(kind: .comment, pattern: "<!--[\\s\\S]*?-->"),
        TokenPattern(kind: .preprocessor, pattern: "^#{1,6}\\s+.*$", options: [.anchorsMatchLines]),
        TokenPattern(kind: .string,  pattern: "```[\\s\\S]*?```"),
        TokenPattern(kind: .string,  pattern: "`[^`]+`"),
        TokenPattern(kind: .keyword, pattern: "^\\s*[-*+]\\s|^\\s*\\d+\\.\\s", options: [.anchorsMatchLines]),
        TokenPattern(kind: .attribute, pattern: "\\[.*?\\](?:\\(.*?\\)|\\[.*?\\])?"),
        TokenPattern(kind: .xmlTag,  pattern: "\\*\\*.*?\\*\\*|__.*?__"),
        TokenPattern(kind: .functionCall, pattern: "\\*.*?\\*|_.*?_"),
    ]}
}

// MARK: - Syntax Highlighter

/// Applies syntax token colors to an `NSTextStorage` using pre-compiled regex patterns.
///
/// Design constraints:
/// - All mutation happens on the main thread via DispatchQueue.main.async.
/// - `NSTextStorageDelegate` callbacks are `nonisolated`; they capture only value types
///   and dispatch to main for actual storage mutation.
/// - Per-language pattern sets are compiled once and cached.
/// - Only the edited range (extended to line boundaries) is re-highlighted on incremental
///   edits to keep keystroke latency minimal.
final class SyntaxHighlighter: NSObject, NSTextStorageDelegate {

    // MARK: - Shared Pattern Cache (accessed only on main thread)

    private static var patternCache: [SyntaxLanguage: [TokenPattern]] = [:]

    private static func patterns(for language: SyntaxLanguage) -> [TokenPattern] {
        assert(Thread.isMainThread)
        if let cached = patternCache[language] { return cached }
        let built = SyntaxPatternLibrary.patterns(for: language)
        patternCache[language] = built
        return built
    }

    // MARK: - Properties (main-thread only)

    private let language: SyntaxLanguage
    private var defaultColor: NSColor
    private weak var textStorage: NSTextStorage?
    private var isDeferredFullHighlightScheduled = false
    private var isApplyingHighlight = false

    // MARK: - Init

    init(language: SyntaxLanguage, defaultColor: NSColor) {
        self.language = language
        self.defaultColor = defaultColor
    }

    func attach(to textStorage: NSTextStorage) {
        assert(Thread.isMainThread)
        self.textStorage = textStorage
        textStorage.delegate = self
    }

    func updateDefaultColor(_ color: NSColor) {
        assert(Thread.isMainThread)
        guard color != defaultColor else { return }
        defaultColor = color
        // Re-highlight entirely when theme changes (e.g. light/dark mode switch).
        scheduleFullHighlight()
    }

    // MARK: - NSTextStorageDelegate

    // Called from NSTextStorage internals; may or may not be on main thread.
    override func textStorageDidProcessEditing(_ notification: Notification) {
        guard let storage = notification.object as? NSTextStorage else { return }
        // Capture value types before hopping to main.
        let editedMask = storage.editedMask
        let editedRange = storage.editedRange
        DispatchQueue.main.async { [weak self, weak storage] in
            guard let self, let storage else { return }
            self.handleStorageEdited(storage: storage, editedMask: editedMask, editedRange: editedRange)
        }
    }

    // MARK: - Highlight Logic

    private func handleStorageEdited(
        storage: NSTextStorage,
        editedMask: NSTextStorageEditActions,
        editedRange: NSRange
    ) {
        assert(Thread.isMainThread)
        guard !isApplyingHighlight else { return }
        // Highlight only on character changes (not just attribute changes).
        guard editedMask.contains(.editedCharacters) else { return }

        // Extend to full lines for multi-line patterns.
        let lineRange = extendToLines(editedRange, in: storage.string as NSString)
        highlight(range: lineRange, in: storage)
    }

    private func scheduleFullHighlight() {
        assert(Thread.isMainThread)
        guard !isDeferredFullHighlightScheduled else { return }
        isDeferredFullHighlightScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.isDeferredFullHighlightScheduled = false
            guard let self, let storage = self.textStorage else { return }
            self.highlight(range: NSRange(location: 0, length: storage.length), in: storage)
        }
    }

    func highlightAll() {
        assert(Thread.isMainThread)
        guard let storage = textStorage else { return }
        let fullRange = NSRange(location: 0, length: storage.length)
        guard fullRange.length > 0 else { return }
        highlight(range: fullRange, in: storage)
    }

    private func highlight(range: NSRange, in storage: NSTextStorage) {
        guard range.length > 0, range.location + range.length <= storage.length else { return }
        let patterns = Self.patterns(for: language)
        guard !patterns.isEmpty else { return }

        let isDark = !defaultColor.isLight
        let theme = SyntaxTheme.make(forDark: isDark)
        let text = storage.string as NSString

        isApplyingHighlight = true
        storage.beginEditing()

        // Reset the range to the default foreground color.
        storage.addAttribute(.foregroundColor, value: defaultColor, range: range)

        // Apply each pattern in declaration order.
        // Later patterns do NOT overwrite earlier ones (comment/string must come first).
        var occupied = [NSRange]()

        for pattern in patterns {
            let tokenColor = theme.color(for: pattern.kind)
            let searchRange = constrainRange(range, to: text.length)
            guard searchRange.length > 0 else { continue }

            pattern.regex.enumerateMatches(
                in: storage.string,
                options: [],
                range: searchRange
            ) { match, _, _ in
                guard let match else { return }
                let matchRange = match.range
                guard matchRange.length > 0 else { return }
                // Don't paint over already-claimed ranges (e.g. comments over keywords).
                guard !occupied.contains(where: { NSIntersectionRange($0, matchRange).length > 0 }) else { return }
                storage.addAttribute(.foregroundColor, value: tokenColor, range: matchRange)
                occupied.append(matchRange)
            }
        }

        storage.endEditing()
        isApplyingHighlight = false
    }

    // MARK: - Helpers

    private func extendToLines(_ range: NSRange, in text: NSString) -> NSRange {
        guard text.length > 0 else { return NSRange(location: 0, length: 0) }
        let safeEnd = min(NSMaxRange(range), text.length)
        let lineStart = text.lineRange(for: NSRange(location: range.location, length: 0)).location
        let lineEnd = text.lineRange(for: NSRange(location: safeEnd > 0 ? safeEnd - 1 : 0, length: 0))
        let end = NSMaxRange(lineEnd)
        return NSRange(location: lineStart, length: max(0, end - lineStart))
    }

    private func constrainRange(_ range: NSRange, to length: Int) -> NSRange {
        let start = min(range.location, length)
        let end   = min(NSMaxRange(range), length)
        return NSRange(location: start, length: max(0, end - start))
    }
}
