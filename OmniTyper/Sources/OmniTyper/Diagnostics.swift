// SPDX-License-Identifier: Apache-2.0
import Foundation

/// A bounded record of what the app did when something went wrong.
///
/// It stores failure codes and the shape of the situation: which destination,
/// which insertion path, which permission. It never stores a transcript,
/// selected text, field contents, window titles or file paths, so the file can
/// be attached to a report without reading it first. That constraint is the
/// point: a log nobody dares share is a log nobody sends.
enum Diagnostics {
    private static let byteLimit = 128 * 1024
    private static let lock = NSLock()

    /// Set to write somewhere else; otherwise see `directory`.
    nonisolated(unsafe) static var overrideDirectory: URL?

    private final class Anchor {}

    /// The user's log belongs to the app. A test bundle borrows the same code
    /// and must not append to the log of whoever is running it, and tests run in
    /// parallel, so an override each test sets and clears would be cleared
    /// underneath a test still writing. Deciding by where this code is loaded
    /// from is the only form of this that cannot race. `Bundle.main` is the
    /// SwiftPM test helper under `swift test`, so ask for the bundle carrying
    /// this type instead.
    static var directory: URL? {
        if let overrideDirectory { return overrideDirectory }
        guard !Bundle(for: Anchor.self).bundlePath.hasSuffix(".xctest") else {
            return FileManager.default.temporaryDirectory
                .appendingPathComponent("OmniTyperTests/Logs", isDirectory: true)
        }
        return FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Logs/OmniTyper", isDirectory: true)
    }

    static var fileURL: URL? { directory?.appendingPathComponent("diagnostics.log") }

    /// Anything raised outside the app's own vocabulary logs as `unknown` rather
    /// than as a sentence, which would vary by language and by wording.
    static func code(of error: Error) -> String {
        (error as? Failure)?.code ?? "unknown"
    }

    static func record(_ event: String, _ details: [String: String] = [:]) {
        var fields = ["at": ISO8601DateFormatter().string(from: Date()), "event": event]
        fields.merge(details) { _, new in new }
        let line = fields.keys.sorted()
            .map { "\"\($0)\":\(quote(fields[$0]!))" }
            .joined(separator: ",")
        append("{" + line + "}\n")
    }

    /// Reading the whole file to trim it is affordable at this size and keeps
    /// the format a plain, appendable series of lines.
    private static func append(_ line: String) {
        guard let directory, let fileURL else { return }
        lock.lock()
        defer { lock.unlock() }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var text = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            text += line
            if text.utf8.count > byteLimit {
                let keep = text.suffix(byteLimit / 2)
                text = keep.drop(while: { $0 != "\n" }).dropFirst().isEmpty
                    ? String(keep)
                    : String(keep.drop(while: { $0 != "\n" }).dropFirst())
            }
            try Data(text.utf8).write(to: fileURL, options: .atomic)
        } catch {
            // Note (Jiaxin Deng): Diagnostics must never interrupt dictation.
        }
    }

    private static func quote(_ value: String) -> String {
        var escaped = ""
        for character in value.unicodeScalars {
            switch character {
            case "\"": escaped += "\\\""
            case "\\": escaped += "\\\\"
            case "\n": escaped += "\\n"
            case "\t": escaped += "\\t"
            default:
                escaped += character.value < 0x20 ? String(format: "\\u%04x", character.value) : String(character)
            }
        }
        return "\"" + escaped + "\""
    }
}
