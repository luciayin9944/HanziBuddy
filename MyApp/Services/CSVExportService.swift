import Foundation

enum CSVExportError: LocalizedError {
    case noLearnedCharacters

    var errorDescription: String? {
        "There are no learned characters to export yet."
    }
}

struct CSVExportService {
    func exportLearnedCharacters(_ records: [CharacterRecord]) throws -> URL {
        let learned = records.compactMap { record -> (record: CharacterRecord, date: Date)? in
            guard record.isSaved, let date = record.learnedAt else { return nil }
            return (record, date)
        }
        .sorted {
            if $0.record.character != $1.record.character {
                return $0.record.character < $1.record.character
            }
            return $0.record.id.uuidString < $1.record.id.uuidString
        }

        guard !learned.isEmpty else { throw CSVExportError.noLearnedCharacters }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.formatOptions = [.withFullDate]

        var rows = ["Character,Pinyin,Mastered Date (UTC),Review Count"]
        rows += learned.map { item in
            let fields = [
                item.record.character,
                item.record.savedPronunciations.map(\.pinyin).joined(separator: " / "),
                dateFormatter.string(from: item.date),
                String(item.record.reviewCount)
            ]
            return fields.map(escape).joined(separator: ",")
        }

        let csv = rows.joined(separator: "\r\n") + "\r\n"
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChineseScanner-Learned-\(UUID().uuidString).csv")
        try csv.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    private func escape(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
