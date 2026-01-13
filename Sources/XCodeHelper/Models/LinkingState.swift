import Foundation

/// Info about a saved xcframework reference that was replaced
struct SavedXCFrameworkInfo: Codable {
    /// UUID of the PBXFileReference
    let fileReferenceUUID: String

    /// UUIDs of PBXBuildFile entries that reference this framework
    let buildFileUUIDs: [String]

    /// UUID of the group containing the framework (for restoration)
    let groupUUID: String?

    /// Original path of the xcframework
    let originalPath: String

    /// Original name
    let originalName: String
}

/// Represents the current linking state
struct LinkingState: Codable {
    let enabled: Bool
    let mapping: String
    let timestamp: Date

    /// Saved info about the xcframework that was replaced (for restoration on disable)
    let savedXCFrameworkInfo: SavedXCFrameworkInfo?

    private static let stateFileName = ".xcode-helper-state.json"

    /// Write state to the base path
    static func write(
        enabled: Bool,
        mapping: String,
        savedXCFrameworkInfo: SavedXCFrameworkInfo? = nil,
        at basePath: String
    ) throws {
        let state = LinkingState(
            enabled: enabled,
            mapping: mapping,
            timestamp: Date(),
            savedXCFrameworkInfo: savedXCFrameworkInfo
        )
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
