import Foundation

/// Service to manage project file backups
struct BackupManager {
    private let backupDirectory: URL
    private let fileManager = FileManager.default

    init() {
        let home = fileManager.homeDirectoryForCurrentUser
        self.backupDirectory = home
            .appendingPathComponent(".link-framework-cli")
            .appendingPathComponent("backups")
    }

    /// Create backup before modifying a project
    func createBackup(of projectPath: String, mappingId: String) throws -> String {
        // Ensure backup directory exists
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let backupName = "\(mappingId)_\(timestamp)"
        let backupPath = backupDirectory.appendingPathComponent(backupName)

        try fileManager.createDirectory(at: backupPath, withIntermediateDirectories: true)

        // Copy project.pbxproj
        let pbxprojPath = URL(fileURLWithPath: projectPath)
            .appendingPathComponent("project.pbxproj")
        let backupFile = backupPath.appendingPathComponent("project.pbxproj")
        try fileManager.copyItem(at: pbxprojPath, to: backupFile)

        // Save metadata
        let metadata = BackupMetadata(
            originalProjectPath: projectPath,
            mappingId: mappingId,
            timestamp: Date()
        )
        let metadataPath = backupPath.appendingPathComponent("metadata.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(metadata)
        try data.write(to: metadataPath)

        return backupPath.path
    }

    /// Restore from most recent backup for a mapping
    func restoreLatestBackup(for mappingId: String) throws {
        guard let latestBackup = try findLatestBackup(for: mappingId) else {
            throw BackupError.noBackupFound(mappingId)
        }

        // Read metadata
        let metadataPath = latestBackup.appendingPathComponent("metadata.json")
        let data = try Data(contentsOf: metadataPath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let metadata = try decoder.decode(BackupMetadata.self, from: data)

        // Restore project.pbxproj
        let backupFile = latestBackup.appendingPathComponent("project.pbxproj")
        let originalPath = URL(fileURLWithPath: metadata.originalProjectPath)
            .appendingPathComponent("project.pbxproj")

        // Remove existing file and copy backup
        try? fileManager.removeItem(at: originalPath)
        try fileManager.copyItem(at: backupFile, to: originalPath)

        // Clean up backup after successful restore
        try? fileManager.removeItem(at: latestBackup)
    }

    /// Check if backup exists for a mapping
    func hasBackup(for mappingId: String) throws -> Bool {
        return try findLatestBackup(for: mappingId) != nil
    }

    private func findLatestBackup(for mappingId: String) throws -> URL? {
        guard fileManager.fileExists(atPath: backupDirectory.path) else {
            return nil
        }

        let contents = try fileManager.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: nil
        )

        return contents
            .filter { $0.lastPathComponent.hasPrefix(mappingId) }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .first
    }
}

/// Metadata stored with each backup
private struct BackupMetadata: Codable {
    let originalProjectPath: String
    let mappingId: String
    let timestamp: Date
}
