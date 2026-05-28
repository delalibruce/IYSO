import Foundation
import Photos

enum DateSearchQuery: Equatable {
    case exactDay(month: Int, day: Int, year: Int?)
    case month(month: Int, year: Int?)
    case year(Int)
    case textFallback(String)
}

enum AlbumSearchUtility {
    private static let calendar = Calendar.current

    private static let monthNames: [String: Int] = [
        "jan": 1, "january": 1,
        "feb": 2, "february": 2,
        "mar": 3, "march": 3,
        "apr": 4, "april": 4,
        "may": 5,
        "jun": 6, "june": 6,
        "jul": 7, "july": 7,
        "aug": 8, "august": 8,
        "sep": 9, "sept": 9, "september": 9,
        "oct": 10, "october": 10,
        "nov": 11, "november": 11,
        "dec": 12, "december": 12,
    ]

    // MARK: - Public API

    static func normalizeSearchString(_ input: String) -> String {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        s = s.replacingOccurrences(
            of: #"(\d+)\s*(st|nd|rd|th)\b"#,
            with: "$1",
            options: .regularExpression
        )
        let punctuation = CharacterSet(charactersIn: "./-,")
        s = s.unicodeScalars.map { punctuation.contains($0) ? " " : Character($0) }.map(String.init).joined()
        return s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func parseDateSearchQuery(_ input: String) -> DateSearchQuery? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = normalizeSearchString(trimmed)

        if let compact = parseCompactNumeric(trimmed) {
            return compact
        }

        if let yearOnly = parseYearOnly(normalized) {
            return yearOnly
        }

        if let monthQuery = parseMonthNameQuery(normalized) {
            return monthQuery
        }

        if let numeric = parseSeparatedNumeric(normalized) {
            return numeric
        }

        if !normalized.isEmpty {
            return .textFallback(normalized)
        }

        return nil
    }

    static func albumMatchesSearch(
        album: DateAlbum,
        query: String,
        photoNameProvider: ((PHAsset) -> String)? = nil
    ) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if matchesCustomTitle(album: album, query: trimmed) {
            return true
        }

        if let parsed = parseDateSearchQuery(trimmed), matchesDateQuery(album: album, query: parsed) {
            return true
        }

        if matchesPhotoFileNames(album: album, query: trimmed, photoNameProvider: photoNameProvider) {
            return true
        }

        return matchesTextFallback(album: album, normalizedQuery: normalizeSearchString(trimmed))
    }

    static func filterAlbums(
        _ albums: [DateAlbum],
        query: String,
        photoNameProvider: ((PHAsset) -> String)? = nil
    ) -> [DateAlbum] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return albums.filter {
            albumMatchesSearch(
                album: $0,
                query: trimmed,
                photoNameProvider: photoNameProvider
            )
        }
    }

    // MARK: - Date matching

    static func albumDayComponents(for album: DateAlbum) -> [(month: Int, day: Int, year: Int)] {
        var seenKeys = Set<String>()
        var components: [(month: Int, day: Int, year: Int)] = []

        for asset in album.assets {
            guard let date = asset.creationDate else { continue }
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            guard let year = parts.year, let month = parts.month, let day = parts.day else { continue }
            let key = "\(year)-\(month)-\(day)"
            guard seenKeys.insert(key).inserted else { continue }
            components.append((month, day, year))
        }

        if components.isEmpty {
            let parts = calendar.dateComponents([.year, .month, .day], from: album.date)
            if let year = parts.year, let month = parts.month, let day = parts.day {
                components.append((month, day, year))
            }
        }

        return components
    }

    private static func matchesDateQuery(album: DateAlbum, query: DateSearchQuery) -> Bool {
        let days = albumDayComponents(for: album)

        switch query {
        case .exactDay(let month, let day, let year):
            return days.contains { component in
                component.month == month
                    && component.day == day
                    && (year == nil || component.year == year)
            }

        case .month(let month, let year):
            return days.contains { component in
                component.month == month && (year == nil || component.year == year)
            }

        case .year(let year):
            return days.contains { $0.year == year }

        case .textFallback(let text):
            return matchesTextFallback(album: album, normalizedQuery: text)
        }
    }

    private static func matchesTextFallback(album: DateAlbum, normalizedQuery: String) -> Bool {
        guard !normalizedQuery.isEmpty else { return false }

        let dateLabel = normalizeSearchString(album.canonicalDateLabel)
        if dateLabel.contains(normalizedQuery) { return true }

        let compactQuery = normalizedQuery.replacingOccurrences(of: " ", with: "")
        let compactKey = album.dateKey.replacingOccurrences(of: "-", with: "")
        if compactKey.contains(compactQuery) { return true }

        let dottedLabel = dateLabel.replacingOccurrences(of: " ", with: "")
        if dottedLabel.contains(compactQuery) { return true }

        return false
    }

    // MARK: - Name matching

    private static func matchesCustomTitle(album: DateAlbum, query: String) -> Bool {
        guard let title = album.customTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else { return false }

        let normalizedTitle = normalizeSearchString(title)
        let normalizedQuery = normalizeSearchString(query)
        guard !normalizedQuery.isEmpty else { return false }

        if normalizedTitle.contains(normalizedQuery) { return true }

        let words = normalizedQuery.split(separator: " ").map(String.init)
        if words.count > 1 {
            return words.allSatisfy { normalizedTitle.contains($0) }
        }

        return false
    }

    private static func matchesPhotoFileNames(
        album: DateAlbum,
        query: String,
        photoNameProvider: ((PHAsset) -> String)?
    ) -> Bool {
        let normalizedQuery = normalizeSearchString(query)
        guard !normalizedQuery.isEmpty else { return false }
        let queryTokens = normalizedQuery.split(separator: " ").map(String.init)

        return album.assets.contains { asset in
            let displayName = normalizeSearchString(photoNameProvider?(asset) ?? "")
            let originalName = normalizeSearchString(
                PHAssetResource.assetResources(for: asset).first?.originalFilename ?? ""
            )

            let candidates = [displayName, originalName].filter { !$0.isEmpty }
            guard !candidates.isEmpty else { return false }

            for candidate in candidates {
                if candidate.contains(normalizedQuery) {
                    return true
                }
                if queryTokens.count > 1 && queryTokens.allSatisfy({ candidate.contains($0) }) {
                    return true
                }
            }
            return false
        }
    }

    // MARK: - Parsing helpers

    private static func parseYearOnly(_ normalized: String) -> DateSearchQuery? {
        guard normalized.range(of: #"^\d{4}$"#, options: .regularExpression) != nil,
              let year = Int(normalized) else { return nil }
        return .year(year)
    }

    private static func parseCompactNumeric(_ input: String) -> DateSearchQuery? {
        let digits = input.filter(\.isNumber)
        guard digits.count == 6 || digits.count == 8 else { return nil }

        switch digits.count {
        case 6:
            guard let month = intPrefix(digits, length: 2),
                  let day = intSlice(digits, start: 2, length: 2),
                  let yy = intSuffix(digits, length: 2),
                  isValidMonthDay(month: month, day: day) else { return nil }
            return .exactDay(month: month, day: day, year: expandTwoDigitYear(yy))

        case 8:
            guard let month = intPrefix(digits, length: 2),
                  let day = intSlice(digits, start: 2, length: 2),
                  let year = intSuffix(digits, length: 4),
                  isValidMonthDay(month: month, day: day) else { return nil }
            return .exactDay(month: month, day: day, year: year)

        default:
            return nil
        }
    }

    private static func parseMonthNameQuery(_ normalized: String) -> DateSearchQuery? {
        let tokens = normalized.split(separator: " ").map(String.init)
        guard let first = tokens.first, let month = monthNames[first] else { return nil }

        switch tokens.count {
        case 1:
            return .month(month: month, year: nil)

        case 2:
            if let year = parseYearToken(tokens[1]) {
                return .month(month: month, year: year)
            }
            if let day = Int(tokens[1]), isValidMonthDay(month: month, day: day) {
                return .exactDay(month: month, day: day, year: nil)
            }
            return nil

        default:
            guard tokens.count >= 2, let day = Int(tokens[1]), isValidMonthDay(month: month, day: day) else {
                return nil
            }
            if tokens.count >= 3, let year = parseYearToken(tokens[2]) {
                return .exactDay(month: month, day: day, year: year)
            }
            return .exactDay(month: month, day: day, year: nil)
        }
    }

    private static func parseSeparatedNumeric(_ normalized: String) -> DateSearchQuery? {
        let tokens = normalized.split(separator: " ").map(String.init)
        guard !tokens.isEmpty, tokens.allSatisfy({ $0.allSatisfy(\.isNumber) }) else { return nil }

        switch tokens.count {
        case 1:
            guard let month = Int(tokens[0]), (1...12).contains(month) else { return nil }
            return .month(month: month, year: nil)

        case 2:
            guard let month = Int(tokens[0]), let second = Int(tokens[1]) else { return nil }

            if (1...12).contains(month), (1...31).contains(second), isValidMonthDay(month: month, day: second) {
                return .exactDay(month: month, day: second, year: nil)
            }

            if (1...12).contains(month), let year = parseYearToken(tokens[1]) {
                return .month(month: month, year: year)
            }

            return nil

        case 3:
            guard let month = Int(tokens[0]),
                  let day = Int(tokens[1]),
                  let year = parseYearToken(tokens[2]),
                  isValidMonthDay(month: month, day: day) else { return nil }
            return .exactDay(month: month, day: day, year: year)

        default:
            return nil
        }
    }

    private static func parseYearToken(_ token: String) -> Int? {
        guard let value = Int(token) else { return nil }
        if token.count == 4 { return value }
        if token.count == 2 { return expandTwoDigitYear(value) }
        return nil
    }

    private static func expandTwoDigitYear(_ yy: Int) -> Int {
        2000 + yy
    }

    private static func isValidMonthDay(month: Int, day: Int) -> Bool {
        guard (1...12).contains(month), (1...31).contains(day) else { return false }
        var components = DateComponents()
        components.year = 2000
        components.month = month
        components.day = day
        return calendar.date(from: components) != nil
    }

    private static func intPrefix(_ s: String, length: Int) -> Int? {
        Int(String(s.prefix(length)))
    }

    private static func intSuffix(_ s: String, length: Int) -> Int? {
        Int(String(s.suffix(length)))
    }

    private static func intSlice(_ s: String, start: Int, length: Int) -> Int? {
        let begin = s.index(s.startIndex, offsetBy: start)
        let end = s.index(begin, offsetBy: length)
        return Int(String(s[begin..<end]))
    }
}
