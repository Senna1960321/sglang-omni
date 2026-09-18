// SPDX-License-Identifier: Apache-2.0
import Testing
import Foundation
import Combine
@testable import OmniTyper

struct LocalizationTests {
    private static func table(_ language: String) throws -> [String: String] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/OmniTyper/Resources/\(language).lproj/Localizable.strings")
        return try #require(NSDictionary(contentsOf: url) as? [String: String],
                            "missing or unreadable strings file: \(url.path)")
    }

    /// A key present in one language and missing from another silently ships the
    /// development string, and a format specifier that disagrees between
    /// languages corrupts or crashes `String(format:)`.
    @Test func everyLanguageDefinesTheSameKeysAndFormatSpecifiers() throws {
        let development = try Self.table(L10n.development)
        #expect(!development.isEmpty)
        func specifiers(_ value: String) -> [String] {
            let pattern = try! NSRegularExpression(pattern: "%(?:[0-9]+\\$)?[@dsf]|%[0-9]*d")
            let range = NSRange(value.startIndex..., in: value)
            return pattern.matches(in: value, range: range).map { (value as NSString).substring(with: $0.range) }
        }
        for language in L10n.supported where language != L10n.development {
            let translated = try Self.table(language)
            #expect(Set(translated.keys) == Set(development.keys),
                    """
                    \(language) is out of sync with \(L10n.development).
                    missing: \(Set(development.keys).subtracting(translated.keys).sorted())
                    extra: \(Set(translated.keys).subtracting(development.keys).sorted())
                    """)
            for (key, value) in development where translated[key] != nil {
                #expect(specifiers(value) == specifiers(translated[key]!),
                        "format specifiers differ for \(key) in \(language)")
            }
        }
        // A backslash survives into a parsed value only when the table escaped it
        // twice, which shows the user "\\n" where a line break was meant.
        for language in L10n.supported {
            for (key, value) in try Self.table(language) where value.contains("\\") {
                Issue.record("\(language) \(key) contains a literal backslash: \(value)")
            }
        }
    }

    /// The parity test above reads the source tables. This exercises the bundle
    /// resolution L10n actually uses; if it regresses, every string silently
    /// degrades to its key and formatted strings drop their arguments.
    @Test func lookupResolvesThroughTheResolvedBundle() throws {
        // Passes the language explicitly: constructing an AppStore rewrites the
        // selected language, and other suites do that in parallel with this one.
        #expect(L10n.string("nav.Home", in: nil) == "Home")
        #expect(L10n.string("nav.Home", in: "zh-Hans") == "首页")
        #expect(String(format: L10n.string("notice.inserted", in: "zh-Hans"), "Safari").contains("Safari"))
        // An unsupported or untranslated choice falls back instead of showing keys.
        #expect(L10n.string("nav.Home", in: "xx") == "Home")
    }

    /// Published properties have no equality check, so a permission poll that
    /// assigned unconditionally redrew every view once a second.
    @Test @MainActor func unchangedPermissionsDoNotRepublish() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = AppModel(store: AppStore(directory: directory))
        defer { model.shutdown() }
        model.refreshPermissions()
        var emissions = 0
        let subscription = model.objectWillChange.sink { _ in emissions += 1 }
        defer { subscription.cancel() }
        model.refreshPermissions()
        model.refreshPermissions()
        #expect(emissions == 0, "refreshPermissions published \(emissions) time(s) without a permission change")
    }
}
