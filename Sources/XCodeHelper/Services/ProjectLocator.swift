import Foundation

/// Result of locating projects
struct LocatedProjects {
    let sourceProjectPath: String
    let targetProjectPath: String
    let basePath: String
}

/// Service to locate projects based on directory structure
struct ProjectLocator {
    private let fileManager = FileManager.default

    /// Locate projects based on current working directory
    func locateProjects(from basePath: String, mapping: FrameworkMapping) throws -> LocatedProjects {
        // Strategy 1: Running from within target repo (e.g., pd-mob-b2c-ios)
        if let projects = tryLocateFromTarget(basePath: basePath, mapping: mapping) {
            return projects
        }

        // Strategy 2: Running from parent directory containing both repos
        if let projects = tryLocateFromParent(basePath: basePath, mapping: mapping) {
            return projects
        }

        throw LinkFrameworkError.projectsNotFound(
            source: mapping.sourceProject.name,
            target: mapping.targetProject.name
        )
    }

    private func tryLocateFromTarget(basePath: String, mapping: FrameworkMapping) -> LocatedProjects? {
        // Check if we're in target repo by looking for its project file
        let targetProjectPath = URL(fileURLWithPath: basePath)
            .appendingPathComponent(mapping.targetProject.projectPath)
            .path

        guard fileManager.fileExists(atPath: targetProjectPath) else {
            return nil
        }

        // Check for source repo as sibling
        let parentPath = URL(fileURLWithPath: basePath).deletingLastPathComponent().path
        let sourceRepoPath = URL(fileURLWithPath: parentPath)
            .appendingPathComponent(mapping.sourceProject.expectedDirectory)
            .path

        guard fileManager.fileExists(atPath: sourceRepoPath) else {
            return nil
        }

        let sourceProjectPath = URL(fileURLWithPath: sourceRepoPath)
            .appendingPathComponent(mapping.sourceProject.projectPath)
            .path

        guard fileManager.fileExists(atPath: sourceProjectPath) else {
            return nil
        }

        return LocatedProjects(
            sourceProjectPath: sourceProjectPath,
            targetProjectPath: targetProjectPath,
            basePath: parentPath
        )
    }

    private func tryLocateFromParent(basePath: String, mapping: FrameworkMapping) -> LocatedProjects? {
        let sourceRepoPath = URL(fileURLWithPath: basePath)
            .appendingPathComponent(mapping.sourceProject.expectedDirectory)
            .path

        let targetRepoPath = URL(fileURLWithPath: basePath)
            .appendingPathComponent(mapping.targetProject.expectedDirectory)
            .path

        guard fileManager.fileExists(atPath: sourceRepoPath),
              fileManager.fileExists(atPath: targetRepoPath) else {
            return nil
        }

        let sourceProjectPath = URL(fileURLWithPath: sourceRepoPath)
            .appendingPathComponent(mapping.sourceProject.projectPath)
            .path

        let targetProjectPath = URL(fileURLWithPath: targetRepoPath)
            .appendingPathComponent(mapping.targetProject.projectPath)
            .path

        guard fileManager.fileExists(atPath: sourceProjectPath),
              fileManager.fileExists(atPath: targetProjectPath) else {
            return nil
        }

        return LocatedProjects(
            sourceProjectPath: sourceProjectPath,
            targetProjectPath: targetProjectPath,
            basePath: basePath
        )
    }
}
