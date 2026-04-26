import Foundation

enum WordRecordStoreError: LocalizedError {
    case couldNotCreateBookmark
    case accessDenied(URL)
    case couldNotWrite(URL)

    var errorDescription: String? {
        switch self {
        case .couldNotCreateBookmark:
            return "Could not save access to the selected file."
        case .accessDenied(let url):
            return "VBRecorder does not have permission to write to \(url.lastPathComponent)."
        case .couldNotWrite(let url):
            return "Could not write to \(url.lastPathComponent)."
        }
    }
}

final class WordRecordStore {
    private enum DefaultsKey {
        static let bookmark = "RecordFileBookmark"
    }

    private struct WordEntry {
        var word: String
        var note: String
        var createdAt: String
        var firstAddedRank: Int
        var lastAccessedAt: String
        var recentAccessRank: Int
    }

    private let defaults: UserDefaults
    private let defaultFileURLOverride: URL?
    private let now: () -> Date

    init(
        defaults: UserDefaults = .standard,
        defaultFileURL: URL? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.defaultFileURLOverride = defaultFileURL
        self.now = now
    }

    private var isSandboxed: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    var currentFileURL: URL {
        (try? resolvedSecurityScopedFileURL()) ?? defaultRecordFileURL
    }

    var isUsingDefaultFile: Bool {
        defaults.data(forKey: DefaultsKey.bookmark) == nil
    }

    var defaultRecordFileURL: URL {
        if let defaultFileURLOverride {
            return defaultFileURLOverride
        }

        let directory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?
            .appendingPathComponent("VBRecorder", isDirectory: true)

        return (directory ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("words.csv")
    }

    func useDefaultFile() {
        defaults.removeObject(forKey: DefaultsKey.bookmark)
    }

    func setRecordFileURL(_ url: URL) throws {
        let accessing = isSandboxed ? url.startAccessingSecurityScopedResource() : false

        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            try createParentDirectory(for: url)
            try createFileIfNeeded(at: url)
        } catch {
            throw mappedWriteError(error, for: url)
        }

        try saveBookmark(for: url)
    }

    @discardableResult
    func append(_ word: String) throws -> URL {
        let file = try resolvedRecordFile()
        let accessing = file.usesSecurityScope
            ? file.url.startAccessingSecurityScopedResource()
            : false

        defer {
            if accessing {
                file.url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            try createParentDirectory(for: file.url)
            try createFileIfNeeded(at: file.url)
            try upsertWord(word, in: file.url)
            return file.url
        } catch {
            throw mappedWriteError(error, for: file.url)
        }
    }

    func ensureCurrentFileExists() throws -> URL {
        let file = try resolvedRecordFile()
        let accessing = file.usesSecurityScope
            ? file.url.startAccessingSecurityScopedResource()
            : false

        defer {
            if accessing {
                file.url.stopAccessingSecurityScopedResource()
            }
        }

        try createParentDirectory(for: file.url)
        try createFileIfNeeded(at: file.url)

        return file.url
    }

    private func upsertWord(_ word: String, in url: URL) throws {
        var entries = try loadEntries(from: url)
        let timestamp = Self.timestampFormatter.string(from: now())
        let nextRecentAccessRank = (entries.map(\.recentAccessRank).max() ?? 0) + 1

        if let index = entries.firstIndex(where: { $0.word == word }) {
            entries[index].lastAccessedAt = timestamp
            entries[index].recentAccessRank = nextRecentAccessRank
        } else {
            let nextFirstAddedRank = (entries.map(\.firstAddedRank).max() ?? 0) + 1
            entries.append(
                WordEntry(
                    word: word,
                    note: "",
                    createdAt: timestamp,
                    firstAddedRank: nextFirstAddedRank,
                    lastAccessedAt: timestamp,
                    recentAccessRank: nextRecentAccessRank
                )
            )
        }

        try writeEntries(entries, to: url)
    }

    private func loadEntries(from url: URL) throws -> [WordEntry] {
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else {
            return []
        }

        let rows = Self.parseCSV(text)
        guard let header = rows.first, !header.isEmpty else {
            return []
        }

        let columns = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($1, $0) })
        let dataRows = rows.dropFirst()

        var entriesByWord: [String: WordEntry] = [:]
        var firstSeenOrder: [String] = []
        var nextLegacyFirstAddedRank = 1
        var nextLegacyRecentAccessRank = 1

        for row in dataRows {
            let word = value(for: "word", in: row, columns: columns).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !word.isEmpty else {
                continue
            }

            let note = value(for: "note", in: row, columns: columns)
            let createdAt = value(for: "created_at", in: row, columns: columns)
            let firstAddedRank = Int(value(for: "first_added_rank", in: row, columns: columns))
            let lastAccessedAtValue = value(for: "last_accessed_at", in: row, columns: columns)
            let recentAccessRank = Int(value(for: "recent_access_rank", in: row, columns: columns))

            if entriesByWord[word] == nil {
                firstSeenOrder.append(word)
                entriesByWord[word] = WordEntry(
                    word: word,
                    note: note,
                    createdAt: createdAt,
                    firstAddedRank: firstAddedRank ?? nextLegacyFirstAddedRank,
                    lastAccessedAt: lastAccessedAtValue.isEmpty ? createdAt : lastAccessedAtValue,
                    recentAccessRank: recentAccessRank ?? nextLegacyRecentAccessRank
                )
                nextLegacyFirstAddedRank += 1
            } else {
                var entry = entriesByWord[word]!
                if entry.note.isEmpty, !note.isEmpty {
                    entry.note = note
                }
                if entry.createdAt.isEmpty, !createdAt.isEmpty {
                    entry.createdAt = createdAt
                }
                if let firstAddedRank {
                    entry.firstAddedRank = min(entry.firstAddedRank, firstAddedRank)
                }
                entry.lastAccessedAt = lastAccessedAtValue.isEmpty ? createdAt : lastAccessedAtValue
                if let recentAccessRank {
                    entry.recentAccessRank = recentAccessRank
                } else {
                    entry.recentAccessRank = nextLegacyRecentAccessRank
                }
                entriesByWord[word] = entry
            }

            nextLegacyRecentAccessRank += 1
        }

        var entries = firstSeenOrder.compactMap { entriesByWord[$0] }
        normalizeFirstAddedRanks(&entries)
        normalizeRecentAccessRanks(&entries)
        return entries
    }

    private func writeEntries(_ entries: [WordEntry], to url: URL) throws {
        let sortedEntries = entries.sorted { lhs, rhs in
            lhs.firstAddedRank < rhs.firstAddedRank
        }

        var lines = [Self.csvHeader]
        lines.append(contentsOf: sortedEntries.map { Self.csvLine(for: $0) })
        let text = lines.joined(separator: "\n") + "\n"
        try text.write(to: url, atomically: true, encoding: String.Encoding.utf8)
    }

    private func normalizeFirstAddedRanks(_ entries: inout [WordEntry]) {
        let orderedWords = entries
            .sorted {
                if $0.firstAddedRank == $1.firstAddedRank {
                    return $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
                }
                return $0.firstAddedRank < $1.firstAddedRank
            }
            .map(\.word)

        var rankByWord: [String: Int] = [:]
        for (index, word) in orderedWords.enumerated() {
            rankByWord[word] = index + 1
        }

        for index in entries.indices {
            entries[index].firstAddedRank = rankByWord[entries[index].word] ?? entries[index].firstAddedRank
        }
    }

    private func normalizeRecentAccessRanks(_ entries: inout [WordEntry]) {
        let orderedWords = entries
            .sorted {
                if $0.recentAccessRank == $1.recentAccessRank {
                    return $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
                }
                return $0.recentAccessRank < $1.recentAccessRank
            }
            .map(\.word)

        var rankByWord: [String: Int] = [:]
        for (index, word) in orderedWords.enumerated() {
            rankByWord[word] = index + 1
        }

        for index in entries.indices {
            entries[index].recentAccessRank = rankByWord[entries[index].word] ?? entries[index].recentAccessRank
        }
    }

    private func resolvedRecordFile() throws -> ResolvedRecordFile {
        if let securityScopedURL = try resolvedSecurityScopedFileURL() {
            return ResolvedRecordFile(url: securityScopedURL, usesSecurityScope: isSandboxed)
        }

        return ResolvedRecordFile(url: defaultRecordFileURL, usesSecurityScope: false)
    }

    private func resolvedSecurityScopedFileURL() throws -> URL? {
        guard let bookmarkData = defaults.data(forKey: DefaultsKey.bookmark) else {
            return nil
        }

        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: isSandboxed ? [.withSecurityScope] : [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        if isStale {
            try saveBookmark(for: url)
        }

        return url
    }

    private func saveBookmark(for url: URL) throws {
        do {
            let bookmarkData = try url.bookmarkData(
                options: isSandboxed ? [.withSecurityScope] : [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            defaults.set(bookmarkData, forKey: DefaultsKey.bookmark)
        } catch {
            throw WordRecordStoreError.couldNotCreateBookmark
        }
    }

    private func mappedWriteError(_ error: Error, for url: URL) -> WordRecordStoreError {
        Self.isPermissionError(error) ? .accessDenied(url) : .couldNotWrite(url)
    }

    static func isPermissionError(_ error: Error) -> Bool {
        let nsError = error as NSError

        if nsError.domain == NSCocoaErrorDomain {
            let cocoaPermissionCodes = [
                NSFileReadNoPermissionError,
                NSFileWriteNoPermissionError,
                NSFileWriteVolumeReadOnlyError
            ]

            if cocoaPermissionCodes.contains(nsError.code) {
                return true
            }
        }

        if nsError.domain == NSPOSIXErrorDomain {
            let posixPermissionCodes = [EACCES, EPERM, EROFS].map(Int.init)
            if posixPermissionCodes.contains(nsError.code) {
                return true
            }
        }

        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isPermissionError(underlyingError)
        }

        return false
    }

    private func createParentDirectory(for url: URL) throws {
        let directoryURL = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

    private func createFileIfNeeded(at url: URL) throws {
        guard !FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        let headerData = Data((Self.csvHeader + "\n").utf8)

        if !FileManager.default.createFile(atPath: url.path, contents: headerData) {
            throw WordRecordStoreError.couldNotWrite(url)
        }
    }

    private func value(for name: String, in row: [String], columns: [String: Int]) -> String {
        guard let index = columns[name], row.indices.contains(index) else {
            return ""
        }

        return row[index]
    }

    private static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var insideQuotes = false
        var iterator = text.makeIterator()

        while let character = iterator.next() {
            if insideQuotes {
                if character == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" {
                            field.append("\"")
                        } else {
                            insideQuotes = false
                            if next == "," {
                                row.append(field)
                                field = ""
                            } else if next == "\n" {
                                row.append(field)
                                rows.append(row)
                                row = []
                                field = ""
                            } else if next == "\r" {
                                if let after = iterator.next(), after != "\n" {
                                    field.append(after)
                                }
                                row.append(field)
                                rows.append(row)
                                row = []
                                field = ""
                            } else {
                                field.append(next)
                            }
                        }
                    } else {
                        insideQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else {
                switch character {
                case "\"":
                    insideQuotes = true
                case ",":
                    row.append(field)
                    field = ""
                case "\n":
                    row.append(field)
                    rows.append(row)
                    row = []
                    field = ""
                case "\r":
                    continue
                default:
                    field.append(character)
                }
            }
        }

        if insideQuotes || !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        return rows
    }

    private static func csvLine(for entry: WordEntry) -> String {
        [
            csvField(entry.word),
            csvField(entry.note),
            csvField(entry.createdAt),
            csvField(String(entry.firstAddedRank)),
            csvField(entry.lastAccessedAt),
            csvField(String(entry.recentAccessRank))
        ].joined(separator: ",")
    }

    private static let csvHeader = "word,note,created_at,first_added_rank,last_accessed_at,recent_access_rank"

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static func csvField(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private struct ResolvedRecordFile {
        let url: URL
        let usesSecurityScope: Bool
    }
}
