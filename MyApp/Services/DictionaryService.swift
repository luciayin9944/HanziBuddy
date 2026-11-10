import Foundation
import SQLite3

enum DictionaryError: LocalizedError {
    case missingDatabase
    case unsupportedCharacter
    case missingPronunciation
    case databaseFailure(String)

    var errorDescription: String? {
        switch self {
        case .missingDatabase:
            "The Chinese dictionary is missing from this app."
        case .unsupportedCharacter:
            "This character is outside the current 3,500-character dictionary."
        case .missingPronunciation:
            "The dictionary has no pronunciation for this character."
        case .databaseFailure:
            "The Chinese dictionary could not be read. Try again."
        }
    }
}

/// Reads the bundled dictionary without changing it or copying it into user storage.
struct DictionaryService {
    let databaseURL: URL?

    init(databaseURL: URL? = Bundle.main.url(forResource: "cedict", withExtension: "sqlite")) {
        self.databaseURL = databaseURL
    }

    func pronunciations(for character: String) throws -> [CharacterCardView.PronunciationGroup] {
        guard character.unicodeScalars.count == 1,
              character.unicodeScalars.first?.properties.isUnifiedIdeograph == true else {
            throw DictionaryError.unsupportedCharacter
        }
        guard let databaseURL else { throw DictionaryError.missingDatabase }

        var connection: OpaquePointer?
        let status = sqlite3_open_v2(databaseURL.path, &connection, SQLITE_OPEN_READONLY, nil)
        guard status == SQLITE_OK, let connection else {
            sqlite3_close(connection)
            throw DictionaryError.databaseFailure("Could not open database")
        }
        defer { sqlite3_close(connection) }

        guard try contains(character, in: connection) else {
            throw DictionaryError.unsupportedCharacter
        }

        let pronunciations = try loadPronunciations(for: character, from: connection)
        guard !pronunciations.isEmpty else { throw DictionaryError.missingPronunciation }

        return try pronunciations.map { numbered, marked in
            CharacterCardView.PronunciationGroup(
                pinyin: marked,
                examples: try loadExamples(
                    for: character,
                    pronunciation: numbered,
                    from: connection
                )
            )
        }
    }

    /// Returns real words containing the character whose full pinyin differs from the answer.
    func wordDistractors(
        containing character: String,
        excludingPinyin answerPinyin: String,
        excludingWords answerWords: Set<String>
    ) throws -> [String] {
        guard let databaseURL else { throw DictionaryError.missingDatabase }
        var connection: OpaquePointer?
        let status = sqlite3_open_v2(databaseURL.path, &connection, SQLITE_OPEN_READONLY, nil)
        guard status == SQLITE_OK, let connection else {
            sqlite3_close(connection)
            throw DictionaryError.databaseFailure("Could not open database")
        }
        defer { sqlite3_close(connection) }

        let statement = try prepare(
            """
            SELECT DISTINCT w.simplified, w.pinyin, w.character_count, w.definition
            FROM example_matches AS e
            JOIN words AS w ON w.id = e.word_id
            WHERE e.character = ?
            """,
            in: connection
        )
        defer { sqlite3_finalize(statement) }
        try bind(character, at: 1, to: statement, in: connection)

        var pronunciationsByWord: [String: Set<String>] = [:]
        var suitableWords = Set<String>()
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE { break }
            guard result == SQLITE_ROW else { throw failure(in: connection) }
            let word = text(at: 0, in: statement)
            pronunciationsByWord[word, default: []].insert(text(at: 1, in: statement))
            let length = sqlite3_column_int(statement, 2)
            let definition = text(at: 3, in: statement).lowercased()
            if (2...4).contains(length) &&
                !["surname", "variant of", "archaic", "slang", "county", "city"]
                    .contains(where: definition.contains) {
                suitableWords.insert(word)
            }
        }

        return suitableWords.filter { word in
            !answerWords.contains(word) &&
                !pronunciationsByWord[word, default: []].contains(answerPinyin)
        }
        .shuffled()
    }

    private func contains(_ character: String, in connection: OpaquePointer) throws -> Bool {
        let statement = try prepare(
            "SELECT 1 FROM characters WHERE character = ? LIMIT 1",
            in: connection
        )
        defer { sqlite3_finalize(statement) }
        try bind(character, at: 1, to: statement, in: connection)
        let result = sqlite3_step(statement)
        if result == SQLITE_ROW { return true }
        if result == SQLITE_DONE { return false }
        throw failure(in: connection)
    }

    private func loadPronunciations(
        for character: String,
        from connection: OpaquePointer
    ) throws -> [(String, String)] {
        let statement = try prepare(
            "SELECT pinyin_numbered, pinyin FROM pronunciations " +
                "WHERE character = ? ORDER BY pinyin_numbered",
            in: connection
        )
        defer { sqlite3_finalize(statement) }
        try bind(character, at: 1, to: statement, in: connection)

        var result: [(String, String)] = []
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { return result }
            guard status == SQLITE_ROW else { throw failure(in: connection) }
            result.append((text(at: 0, in: statement), text(at: 1, in: statement)))
        }
    }

    private func loadExamples(
        for character: String,
        pronunciation: String,
        from connection: OpaquePointer
    ) throws -> [CharacterCardView.Example] {
        let statement = try prepare(
            """
            SELECT DISTINCT w.simplified, w.pinyin
            FROM example_matches AS e
            JOIN words AS w ON w.id = e.word_id
            WHERE e.character = ? AND e.pinyin_numbered = ?
              AND lower(w.definition) NOT LIKE '%surname%'
              AND lower(w.definition) NOT LIKE '%variant of%'
              AND lower(w.definition) NOT LIKE '%archaic%'
              AND lower(w.definition) NOT LIKE '%slang%'
              AND lower(w.definition) NOT LIKE '%county%'
              AND lower(w.definition) NOT LIKE '%city%'
            ORDER BY w.character_count, length(w.definition), w.simplified
            LIMIT 2
            """,
            in: connection
        )
        defer { sqlite3_finalize(statement) }
        try bind(character, at: 1, to: statement, in: connection)
        try bind(pronunciation, at: 2, to: statement, in: connection)

        var result: [CharacterCardView.Example] = []
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { return result }
            guard status == SQLITE_ROW else { throw failure(in: connection) }
            result.append(.init(word: text(at: 0, in: statement), pinyin: text(at: 1, in: statement)))
        }
    }

    private func prepare(_ sql: String, in connection: OpaquePointer) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw failure(in: connection)
        }
        return statement
    }

    private func bind(
        _ value: String,
        at index: Int32,
        to statement: OpaquePointer,
        in connection: OpaquePointer
    ) throws {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let result = value.withCString {
            sqlite3_bind_text(statement, index, $0, -1, transient)
        }
        guard result == SQLITE_OK else { throw failure(in: connection) }
    }

    private func text(at index: Int32, in statement: OpaquePointer) -> String {
        guard let bytes = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: UnsafeRawPointer(bytes).assumingMemoryBound(to: CChar.self))
    }

    private func failure(in connection: OpaquePointer) -> DictionaryError {
        .databaseFailure(String(cString: sqlite3_errmsg(connection)))
    }
}
