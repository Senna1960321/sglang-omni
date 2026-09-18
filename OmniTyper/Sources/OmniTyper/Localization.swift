// SPDX-License-Identifier: Apache-2.0
import Foundation

/// Interface strings.
///
/// Lookups resolve at call time, so the interface language picker takes effect
/// immediately: views re-render when preferences publish and every visible
/// string is read again from the selected localization.
///
/// Values that are persisted or sent to the worker (writing styles, speech
/// languages, voice modes, appearance) keep their English identifiers; only
/// their labels pass through here.
enum L10n {
    static let development = "en"
    static let supported = ["en", "zh-Hans"]

    /// Errors are built on the audio and worker threads, so every lookup can run
    /// off the main actor while the picker writes the language from it.
    private static let state = NSLock()
    nonisolated(unsafe) private static var selected: String?
    nonisolated(unsafe) private static var cache: [String: Bundle] = [:]

    /// `nil` follows the localization macOS picked for the app.
    static var language: String? { state.withLock { selected } }

    static func use(_ language: String?) {
        let resolved = language.flatMap { supported.contains($0) ? $0 : nil }
        state.withLock { selected = resolved }
    }

    /// Written in the language it names, so someone who cannot read the current
    /// interface language can still find their own in the picker.
    static func displayName(_ language: String) -> String {
        Locale(identifier: language).localizedString(forIdentifier: language)?.localizedCapitalized ?? language
    }

    /// The built app carries its localizations in `Contents/Resources`; tests and
    /// command-line runs read the bundle SwiftPM builds next to the executable.
    /// Resolving it here rather than through the generated `Bundle.module`
    /// accessor avoids that accessor's `fatalError` and its absolute build path.
    private final class Anchor {}

    private static let resources: Bundle = {
        if Bundle.main.path(forResource: development, ofType: "lproj") != nil { return .main }
        // Note (Jiaxin Deng): SwiftPM writes the resources into a bundle beside the product
        // that links them, so the search has to follow the product rather than a
        // fixed path: next to the executable for `swift run`, next to the .xctest
        // bundle for tests.
        let name = "OmniTyper_OmniTyper.bundle"
        var directory = Bundle(for: Anchor.self).bundleURL
        for _ in 0..<3 {
            if let bundle = Bundle(url: directory.appendingPathComponent(name)) { return bundle }
            directory.deleteLastPathComponent()
        }
        return .main
    }()

    /// SwiftPM lowercases `.lproj` directory names, so match them case-insensitively.
    private static func bundle(_ language: String) -> Bundle? {
        state.withLock {
            if let cached = cache[language] { return cached }
            let name = resources.localizations.first { $0.caseInsensitiveCompare(language) == .orderedSame } ?? language
            guard let path = resources.path(forResource: name, ofType: "lproj"),
                  let bundle = Bundle(path: path) else { return nil }
            cache[language] = bundle
            return bundle
        }
    }

    static func string(_ key: String) -> String { string(key, in: language) }

    static func string(_ key: String, in language: String?) -> String {
        let missing = "\u{0}"
        func lookup(_ source: Bundle?) -> String? {
            guard let source else { return nil }
            let value = source.localizedString(forKey: key, value: missing, table: nil)
            return value == missing ? nil : value
        }
        // Note (Jiaxin Deng): An explicit choice wins; otherwise Bundle.main resolves the
        // system's preferred localization. Either way an untranslated key falls back
        // to the development language, because a raw key on screen is worse than a
        // sentence in the wrong language.
        if let value = lookup(language.flatMap(bundle) ?? resources) { return value }
        if let value = lookup(bundle(development)) { return value }
        return key
    }
}

func L(_ key: String) -> String { L10n.string(key) }

func L(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: L10n.string(key), arguments: arguments)
}
