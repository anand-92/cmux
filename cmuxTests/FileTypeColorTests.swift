import XCTest
import AppKit

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

final class FileTypeColorTests: XCTestCase {

    // MARK: - Directories

    func testDirectoriesAlwaysReturnNil() {
        XCTAssertNil(FileTypeColor.nsColor(for: "src", isDirectory: true))
        XCTAssertNil(FileTypeColor.nsColor(for: "node_modules", isDirectory: true))
        XCTAssertNil(FileTypeColor.nsColor(for: "MyFile.swift", isDirectory: true))
    }

    // MARK: - Unknown types fall through

    func testUnknownExtensionReturnsNil() {
        XCTAssertNil(FileTypeColor.nsColor(for: "binary.exe", isDirectory: false))
        XCTAssertNil(FileTypeColor.nsColor(for: "data.frobnicle", isDirectory: false))
    }

    func testFileWithNoExtensionAndNoRoleReturnsNil() {
        XCTAssertNil(FileTypeColor.nsColor(for: "LICENSE", isDirectory: false))
        XCTAssertNil(FileTypeColor.nsColor(for: "Procfile", isDirectory: false))
    }

    // MARK: - Swift

    func testSwiftFileReturnsNonNilColor() {
        let color = FileTypeColor.nsColor(for: "ContentView.swift", isDirectory: false)
        XCTAssertNotNil(color)
    }

    func testSwiftFileCaseInsensitive() {
        let lower = FileTypeColor.nsColor(for: "main.swift", isDirectory: false)
        let upper = FileTypeColor.nsColor(for: "Main.SWIFT", isDirectory: false)
        XCTAssertNotNil(lower)
        XCTAssertNotNil(upper)
        // Both should resolve to the same color
        XCTAssertEqual(lower, upper)
    }

    // MARK: - TypeScript / JavaScript

    func testTypeScriptReturnsNonNilColor() {
        XCTAssertNotNil(FileTypeColor.nsColor(for: "index.ts", isDirectory: false))
        XCTAssertNotNil(FileTypeColor.nsColor(for: "App.tsx", isDirectory: false))
    }

    func testJavaScriptReturnsNonNilColor() {
        XCTAssertNotNil(FileTypeColor.nsColor(for: "index.js", isDirectory: false))
        XCTAssertNotNil(FileTypeColor.nsColor(for: "app.jsx", isDirectory: false))
    }

    func testTypeScriptAndJavaScriptGetDistinctColors() {
        let ts = FileTypeColor.nsColor(for: "file.ts", isDirectory: false)
        let js = FileTypeColor.nsColor(for: "file.js", isDirectory: false)
        XCTAssertNotNil(ts)
        XCTAssertNotNil(js)
        XCTAssertNotEqual(ts, js, "TS and JS should have distinct colors")
    }

    // MARK: - Markdown

    func testMarkdownReturnsNonNilColor() {
        XCTAssertNotNil(FileTypeColor.nsColor(for: "README.md", isDirectory: false))
        XCTAssertNotNil(FileTypeColor.nsColor(for: "guide.mdx", isDirectory: false))
        XCTAssertNotNil(FileTypeColor.nsColor(for: "NOTES.markdown", isDirectory: false))
    }

    // MARK: - JSON / config files

    func testJSONReturnsNonNilColor() {
        XCTAssertNotNil(FileTypeColor.nsColor(for: "config.json", isDirectory: false))
    }

    func testYAMLReturnsNonNilColor() {
        XCTAssertNotNil(FileTypeColor.nsColor(for: "ci.yml", isDirectory: false))
        XCTAssertNotNil(FileTypeColor.nsColor(for: "docker-compose.yaml", isDirectory: false))
    }

    // MARK: - Image / assets

    func testImageExtensionsReturnNonNilColor() {
        for ext in ["png", "jpg", "jpeg", "gif", "webp", "svg", "ico"] {
            XCTAssertNotNil(
                FileTypeColor.nsColor(for: "image.\(ext)", isDirectory: false),
                "Expected non-nil color for extension .\(ext)"
            )
        }
    }

    // MARK: - Shell / scripts

    func testShellScriptReturnsNonNilColor() {
        XCTAssertNotNil(FileTypeColor.nsColor(for: "setup.sh", isDirectory: false))
        XCTAssertNotNil(FileTypeColor.nsColor(for: "run.bash", isDirectory: false))
        XCTAssertNotNil(FileTypeColor.nsColor(for: "deploy.zsh", isDirectory: false))
    }

    // MARK: - Filename-role mappings

    func testReadmeRoleMapping() {
        XCTAssertNotNil(FileTypeColor.nsColor(for: "README.md", isDirectory: false))
        XCTAssertNotNil(FileTypeColor.nsColor(for: "readme", isDirectory: false))
    }

    func testDockerfileRoleMapping() {
        XCTAssertNotNil(FileTypeColor.nsColor(for: "Dockerfile", isDirectory: false))
        XCTAssertNotNil(FileTypeColor.nsColor(for: "dockerfile.dev", isDirectory: false))
    }

    func testPackageJsonRoleMapping() {
        XCTAssertNotNil(FileTypeColor.nsColor(for: "package.json", isDirectory: false))
    }

    func testGitignoreRoleMapping() {
        XCTAssertNotNil(FileTypeColor.nsColor(for: ".gitignore", isDirectory: false))
    }

    // MARK: - Determinism

    func testResolverIsDeterministic() {
        let extensions = ["swift", "ts", "js", "md", "json", "yaml", "sh", "py", "rb", "go", "rs"]
        for ext in extensions {
            let first = FileTypeColor.nsColor(for: "file.\(ext)", isDirectory: false)
            let second = FileTypeColor.nsColor(for: "file.\(ext)", isDirectory: false)
            XCTAssertEqual(first, second, "Color for .\(ext) must be deterministic")
        }
    }

    // MARK: - SwiftUI Color wrapper

    func testSwiftUIColorMirrorsNSColor() {
        let nsColor = FileTypeColor.nsColor(for: "App.swift", isDirectory: false)
        let swiftUIColor = FileTypeColor.color(for: "App.swift", isDirectory: false)
        if nsColor == nil {
            XCTAssertNil(swiftUIColor)
        } else {
            XCTAssertNotNil(swiftUIColor)
        }
    }

    func testDirectoryColorMirrorNilInSwiftUI() {
        XCTAssertNil(FileTypeColor.color(for: "src", isDirectory: true))
    }
}
