import Foundation

enum WordNormalizer {
    static func normalizedWord(from text: String) -> String? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return nil
        }

        let parts = trimmedText.split(whereSeparator: \.isWhitespace)
        guard parts.count == 1 else {
            return nil
        }

        let word = String(parts[0])
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            .lowercased()

        guard !word.isEmpty,
              word.rangeOfCharacter(from: .letters) != nil else {
            return nil
        }

        return word
    }
}
