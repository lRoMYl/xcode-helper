import Foundation

/// Errors that can occur during framework linking operations
enum LinkFrameworkError: LocalizedError {
    case unknownMapping(String, available: [String])
    case projectsNotFound(source: String, target: String)
    case frameworkNotFound(String)
    case projectAlreadyLinked
    case projectNotLinked
    case backupFailed(String)

    var errorDescription: String? {
        switch self {
        case .unknownMapping(let mapping, let available):
            return """
                Unknown mapping: '\(mapping)'
                Available mappings: \(available.joined(separator: ", "))
                """
        case .projectsNotFound(let source, let target):
            return """
                Could not locate both projects:
                  - \(source)
                  - \(target)

                Run this command from:
                  1. Inside the \(target) repository, OR
                  2. A parent directory containing both repositories
                """
        case .frameworkNotFound(let name):
            return "Framework '\(name)' not found in project"
        case .projectAlreadyLinked:
            return "Project is already in linked state. Run 'disable' first."
        case .projectNotLinked:
            return "Project is not in linked state."
        case .backupFailed(let reason):
            return "Backup failed: \(reason)"
        }
    }
}

/// Errors related to backup operations
enum BackupError: LocalizedError {
    case noBackupFound(String)
    case restoreFailed(String)

    var errorDescription: String? {
        switch self {
        case .noBackupFound(let mappingId):
            return "No backup found for mapping '\(mappingId)'"
        case .restoreFailed(let reason):
            return "Restore failed: \(reason)"
        }
    }
}
