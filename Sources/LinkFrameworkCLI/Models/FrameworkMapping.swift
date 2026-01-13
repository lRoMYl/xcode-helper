import Foundation

/// Represents a framework mapping configuration for local debugging
struct FrameworkMapping: Sendable {
    /// Unique identifier for this mapping (e.g., "subscription")
    let id: String

    /// Human-readable name for display
    let displayName: String

    /// The source project (the framework being debugged)
    let sourceProject: ProjectReference

    /// The target project (the app consuming the framework)
    let targetProject: ProjectReference

    /// Framework path remappings
    let frameworkRemappings: [FrameworkRemapping]

    /// Path to add as nested project reference in target (relative to target project)
    let nestedProjectPath: String?
}

/// Reference to a project
struct ProjectReference: Sendable {
    /// Repository/project name (e.g., "pd-mob-subscription-ios")
    let name: String

    /// Relative path to the .xcodeproj within the repository
    let projectPath: String

    /// Expected directory name in the file system
    let expectedDirectory: String
}

/// Represents a framework path remapping
struct FrameworkRemapping: Sendable {
    /// Framework name (e.g., "ApiClient.xcframework")
    let frameworkName: String

    /// Original path when not linked (relative to project)
    let originalPath: String

    /// Path when linked for debugging (relative to project)
    let linkedPath: String
}
