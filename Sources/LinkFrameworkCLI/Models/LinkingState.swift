import Foundation

/// Represents the current linking state
struct LinkingState: Codable {
    let enabled: Bool
    let mapping: String
    let timestamp: Date

    private static let stateFileName = ".link-framework-cli-state.json"

    /// Write state to the base path
    static func write(enabled: Bool, mapping: String, at basePath: String) throws {
        let state = LinkingState(enabled: enabled, mapping: mapping, timestamp: Date())
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)

        let stateFile = URL(fileURLWithPath: basePath).appendingPathComponent(stateFileName)
        try data.write(to: stateFile)
    }

    /// Read state from the base path
    static func read(from basePath: String) throws -> LinkingState {
        let stateFile = URL(fileURLWithPath: basePath).appendingPathComponent(stateFileName)
        let data = try Data(contentsOf: stateFile)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LinkingState.self, from: data)
    }

    /// Clear state file
    static func clear(at basePath: String) throws {
        let stateFile = URL(fileURLWithPath: basePath).appendingPathComponent(stateFileName)
        try? FileManager.default.removeItem(at: stateFile)
    }
}
