import Foundation
import Testing
@testable import VBRecorder

@MainActor
struct VBRecorderTests {
    @Test func normalizesSingleWord() {
        #expect(WordNormalizer.normalizedWord(from: "  Apple,  ") == "apple")
        #expect(WordNormalizer.normalizedWord(from: "can't") == "can't")
        #expect(WordNormalizer.normalizedWord(from: "well-known") == "well-known")
    }

    @Test func rejectsInvalidSelections() {
        #expect(WordNormalizer.normalizedWord(from: "") == nil)
        #expect(WordNormalizer.normalizedWord(from: "hello world") == nil)
        #expect(WordNormalizer.normalizedWord(from: "12345") == nil)
        #expect(WordNormalizer.normalizedWord(from: "...") == nil)
    }

    @Test func appendsWordsToDefaultRecordFile() throws {
        let suiteName = "VBRecorderTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VBRecorderTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("words.csv")
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        var timestamps = [
            Date(timeIntervalSince1970: 1_746_000_000),
            Date(timeIntervalSince1970: 1_746_000_010)
        ]
        let store = WordRecordStore(
            defaults: defaults,
            defaultFileURL: fileURL,
            now: { timestamps.removeFirst() }
        )

        try store.append("apple")
        try store.append("banana")

        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        let expected = """
        word,note,created_at,first_added_rank,last_accessed_at,recent_access_rank
        "apple","","2025-04-30T08:00:00.000Z","1","2025-04-30T08:00:00.000Z","1"
        "banana","","2025-04-30T08:00:10.000Z","2","2025-04-30T08:00:10.000Z","2"
        
        """
        #expect(contents == expected)
    }

    @Test func duplicateWordUpdatesRecentAccessOnly() throws {
        let suiteName = "VBRecorderTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VBRecorderTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("words.csv")
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        var timestamps = [
            Date(timeIntervalSince1970: 1_746_000_000),
            Date(timeIntervalSince1970: 1_746_000_010),
            Date(timeIntervalSince1970: 1_746_000_020)
        ]
        let store = WordRecordStore(
            defaults: defaults,
            defaultFileURL: fileURL,
            now: { timestamps.removeFirst() }
        )

        try store.append("apple")
        try store.append("banana")
        try store.append("apple")

        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        let expected = """
        word,note,created_at,first_added_rank,last_accessed_at,recent_access_rank
        "apple","","2025-04-30T08:00:00.000Z","1","2025-04-30T08:00:20.000Z","3"
        "banana","","2025-04-30T08:00:10.000Z","2","2025-04-30T08:00:10.000Z","2"
        
        """
        #expect(contents == expected)
    }

    @Test func detectsPermissionErrors() {
        let cocoaError = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError)
        #expect(WordRecordStore.isPermissionError(cocoaError))

        let posixError = NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES))
        let wrappedError = NSError(
            domain: NSCocoaErrorDomain,
            code: NSFileWriteUnknownError,
            userInfo: [NSUnderlyingErrorKey: posixError]
        )
        #expect(WordRecordStore.isPermissionError(wrappedError))
    }
}
