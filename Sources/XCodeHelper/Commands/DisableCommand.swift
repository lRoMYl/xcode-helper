import ArgumentParser
import Foundation

struct DisableCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "disable",
        abstract: "Disable local framework linking and restore original configuration"
    )

    @Argument(help: "Framework mapping to disable (e.g., 'subscription')")
    var mapping: String

    @Option(name: .shortAndLong, help: "Path to the project directory")
    var path: String?

    @Flag(name: .shortAndLong, help: "Verbose output")
    var verbose: Bool = false

    mutating func run() async throws {
        let logger = Logger(verbose: verbose)

        logger.info("Disabling framework linking for '\(mapping)'...")

        guard let frameworkMapping = FrameworkMappingRegistry.shared.mapping(for: mapping) else {
            throw LinkFrameworkError.unknownMapping(mapping, available: FrameworkMappingRegistry.shared.availableMappings)
        }

        let basePath = path ?? FileManager.default.currentDirectoryPath
        let locator = ProjectLocator()

        logger.verbose("Looking for projects from: \(basePath)")

        let projects = try locator.locateProjects(from: basePath, mapping: frameworkMapping)

        // Read saved state to get xcframework info
        var savedState: LinkingState?
        do {
            savedState = try LinkingState.read(from: projects.basePath)
        } catch {
            logger.verbose("No saved state found, will use default restoration")
        }

        // Restore source project - remap frameworks back to original paths
        logger.info("Restoring source project...")
        let sourceModifier = try ProjectModifier(projectPath: projects.sourceProjectPath)
        try sourceModifier.remapFrameworks(frameworkMapping.frameworkRemappings, toLinked: false)
        try sourceModifier.save()
        logger.info("Source project frameworks remapped to original paths")

        // Restore target project - replace xcodeproj with xcframework
        if let targetFramework = frameworkMapping.targetFramework {
            logger.info("")
            logger.info("Restoring target project...")

            let targetModifier = try ProjectModifier(projectPath: projects.targetProjectPath)

            // Replace xcodeproj with xcframework
            logger.info("Replacing \(targetFramework.nestedProjectPath) with \(targetFramework.frameworkName)...")
            try targetModifier.replaceXcodeprojWithXCFramework(
                xcodeprojPath: targetFramework.nestedProjectPath,
                frameworkPath: targetFramework.frameworkPath,
                frameworkName: targetFramework.frameworkName,
                savedInfo: savedState?.savedXCFrameworkInfo
            )

            try targetModifier.save()
            logger.info("Target project restored successfully")
        } else if let nestedPath = frameworkMapping.nestedProjectPath {
            // Fallback to just removing nested project (legacy behavior)
            logger.info("")
            logger.info("Removing nested project reference...")
            let targetModifier = try ProjectModifier(projectPath: projects.targetProjectPath)
            try targetModifier.removeNestedProject(at: nestedPath)
            try targetModifier.save()
            logger.info("Nested project reference removed")
        }

        // Clear linking state
        try LinkingState.clear(at: projects.basePath)

        logger.info("")
        logger.success("Framework linking disabled for '\(mapping)'!")
        logger.info("")
        logger.info("The projects have been restored to their original configuration.")
        logger.info("")
        logger.info("You may need to:")
        logger.info("  1. Close and reopen the project in Xcode")
        logger.info("  2. Clean build folder (Cmd+Shift+K)")
    }
}
