import AppKit
import SwiftUI

// MARK: - File Type Color Resolver

/// Resolves a subtle icon-tint color for a given file based on its name or extension.
///
/// Rules:
/// - Directories always return `nil` (callers should use their style-defined folder color).
/// - Filename-role mappings take priority over extension mappings.
/// - Unknown types return `nil` (callers should fall back to the default `fileIconTint`).
/// - All colors are chosen to be legible in both light and dark mode.
/// - No filesystem I/O is performed; resolution is purely based on the filename/extension string.
enum FileTypeColor {

    // MARK: - Public API

    /// Returns the icon tint `NSColor` for the given filename (or nil for unknown/folder).
    static func nsColor(for filename: String, isDirectory: Bool) -> NSColor? {
        guard !isDirectory else { return nil }
        return resolve(filename: filename)
    }

    /// Returns the icon tint SwiftUI `Color` for the given filename (or nil for unknown/folder).
    static func color(for filename: String, isDirectory: Bool) -> Color? {
        guard let ns = nsColor(for: filename, isDirectory: isDirectory) else { return nil }
        return Color(nsColor: ns)
    }

    // MARK: - Internal Resolution

    private static func resolve(filename: String) -> NSColor? {
        let lower = filename.lowercased()

        // --- Filename-role mappings (exact filename, case-insensitive) ---
        switch lower {
        case "readme", "readme.md", "readme.txt", "readme.rst":
            return .systemPurple
        case "dockerfile", "dockerfile.dev", "dockerfile.prod", "dockerfile.staging":
            return .systemCyan
        case "makefile", "rakefile", "gemfile", "podfile", "fastfile":
            return .systemCyan
        case ".gitignore", ".gitattributes", ".gitmodules":
            return .systemGray
        case "package.json", "package-lock.json":
            return .systemGreen
        case "tsconfig.json", "jsconfig.json":
            return .systemBlue
        case ".env", ".env.local", ".env.development", ".env.production", ".env.staging", ".env.test":
            return .systemYellow
        case ".npmrc", ".yarnrc", ".nvmrc", ".tool-versions":
            return .systemTeal
        case "bun.lockb", "yarn.lock", "pnpm-lock.yaml", "cargo.lock":
            return .systemGray
        default:
            break
        }

        // --- Extension mappings ---
        let ext = (filename as NSString).pathExtension.lowercased()
        guard !ext.isEmpty else { return nil }
        return color(forExtension: ext)
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private static func color(forExtension ext: String) -> NSColor? {
        switch ext {

        // Swift / Apple platforms
        case "swift":
            return .systemOrange
        case "m", "mm":
            return .systemOrange.withAlphaComponent(0.85)
        case "h", "hpp", "hh":
            return NSColor(red: 0.75, green: 0.55, blue: 0.30, alpha: 1.0)  // warm tan, adaptive

        // Objective-C / C / C++
        case "c", "cc", "cpp", "cxx", "c++":
            return NSColor(red: 0.50, green: 0.60, blue: 0.85, alpha: 1.0)  // steel blue

        // TypeScript / JavaScript
        case "ts", "tsx":
            return .systemBlue
        case "js", "mjs", "cjs", "jsx":
            return NSColor(red: 0.95, green: 0.77, blue: 0.15, alpha: 1.0)  // JS yellow

        // Web
        case "html", "htm", "xhtml":
            return NSColor(red: 0.90, green: 0.45, blue: 0.20, alpha: 1.0)  // html orange-red
        case "css", "scss", "sass", "less", "styl":
            return NSColor(red: 0.25, green: 0.65, blue: 0.90, alpha: 1.0)  // CSS sky blue
        case "svelte":
            return NSColor(red: 0.95, green: 0.40, blue: 0.25, alpha: 1.0)  // Svelte coral

        // Vue / JSX ecosystem
        case "vue":
            return NSColor(red: 0.25, green: 0.75, blue: 0.55, alpha: 1.0)  // Vue green

        // Python
        case "py", "pyi", "pyx":
            return NSColor(red: 0.30, green: 0.55, blue: 0.85, alpha: 1.0)  // Python blue

        // Ruby
        case "rb", "rake", "gemspec", "ru":
            return NSColor(red: 0.80, green: 0.18, blue: 0.18, alpha: 1.0)  // Ruby red

        // Go
        case "go":
            return NSColor(red: 0.25, green: 0.75, blue: 0.85, alpha: 1.0)  // Go cyan

        // Rust
        case "rs", "toml":
            return NSColor(red: 0.87, green: 0.40, blue: 0.20, alpha: 1.0)  // Rust orange-brown

        // Java / Kotlin / JVM
        case "java":
            return NSColor(red: 0.80, green: 0.30, blue: 0.20, alpha: 1.0)  // Java red-orange
        case "kt", "kts":
            return NSColor(red: 0.55, green: 0.35, blue: 0.85, alpha: 1.0)  // Kotlin purple
        case "scala", "sc":
            return NSColor(red: 0.75, green: 0.20, blue: 0.20, alpha: 1.0)  // Scala red
        case "groovy":
            return NSColor(red: 0.35, green: 0.65, blue: 0.40, alpha: 1.0)  // Groovy green
        case "clj", "cljs", "cljc", "edn":
            return NSColor(red: 0.45, green: 0.75, blue: 0.50, alpha: 1.0)  // Clojure teal-green

        // Shell / scripts
        case "sh", "bash", "zsh", "fish", "ksh", "csh", "tcsh", "command":
            return .systemCyan
        case "ps1", "psm1", "psd1":
            return NSColor(red: 0.30, green: 0.45, blue: 0.80, alpha: 1.0)  // PowerShell blue

        // Markdown / docs
        case "md", "mdx", "markdown":
            return .systemPurple
        case "rst":
            return NSColor(red: 0.60, green: 0.40, blue: 0.80, alpha: 1.0)  // reStructuredText indigo
        case "txt":
            return NSColor(red: 0.65, green: 0.65, blue: 0.65, alpha: 1.0)  // plain text gray
        case "pdf":
            return NSColor(red: 0.82, green: 0.18, blue: 0.15, alpha: 1.0)  // PDF red

        // Data / config
        case "json":
            return NSColor(red: 0.30, green: 0.70, blue: 0.50, alpha: 1.0)  // JSON green
        case "yaml", "yml":
            return NSColor(red: 0.35, green: 0.65, blue: 0.55, alpha: 1.0)  // YAML teal
        case "xml", "plist", "strings", "xcstrings":
            return NSColor(red: 0.50, green: 0.65, blue: 0.40, alpha: 1.0)  // XML olive-green
        case "csv", "tsv":
            return .systemGreen
        case "sql":
            return NSColor(red: 0.55, green: 0.70, blue: 0.40, alpha: 1.0)  // SQL sage

        // Images / assets
        case "png", "jpg", "jpeg", "gif", "webp", "avif", "heic", "heif", "bmp", "tiff", "tif", "ico", "icns":
            return .systemPink
        case "svg":
            return NSColor(red: 0.95, green: 0.55, blue: 0.60, alpha: 1.0)  // SVG rose
        case "xcassets":
            return .systemPink

        // Fonts
        case "ttf", "otf", "woff", "woff2", "eot":
            return NSColor(red: 0.70, green: 0.50, blue: 0.80, alpha: 1.0)  // font lavender

        // Video
        case "mp4", "mov", "avi", "mkv", "webm", "m4v", "mpg", "mpeg":
            return NSColor(red: 0.90, green: 0.35, blue: 0.55, alpha: 1.0)  // video pink-red

        // Audio
        case "mp3", "aac", "m4a", "wav", "ogg", "flac", "aiff":
            return NSColor(red: 0.70, green: 0.40, blue: 0.90, alpha: 1.0)  // audio violet

        // Archives / binary
        case "zip", "tar", "gz", "bz2", "xz", "7z", "rar":
            return NSColor(red: 0.65, green: 0.50, blue: 0.40, alpha: 1.0)  // archive brown

        // Xcode / Apple build
        case "xcodeproj", "xcworkspace", "xctestplan":
            return .systemBlue
        case "xcconfig":
            return NSColor(red: 0.40, green: 0.60, blue: 0.80, alpha: 1.0)  // config blue
        case "entitlements":
            return NSColor(red: 0.30, green: 0.60, blue: 0.45, alpha: 1.0)  // entitlements teal

        // Other
        case "lock":
            return NSColor(red: 0.60, green: 0.60, blue: 0.60, alpha: 1.0)  // lock gray
        case "log":
            return NSColor(red: 0.70, green: 0.65, blue: 0.40, alpha: 1.0)  // log yellow-tan

        default:
            return nil
        }
    }
}
