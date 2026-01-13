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

        let backupManager = BackupManager()

        // Restore source project
        logger.info("Restoring source project from backup...")
        do {
            try backupManager.restoreLatestBackup(for: frameworkMapping.id)
            logger.info("Source project restored successfully")
        } catch BackupError.noBackupFound {
            logger.warning("No backup found for source project. Remapping frameworks manually...")
            let sourceModifier = try ProjectModifier(projectPath: projects.sourceProjectPath)
            try sourceModifier.remapFrameworks(frameworkMapping.frameworkRemappings, toLinked: false)
            try sourceModifier.save()
            logger.info("Source project frameworks remapped to original paths")
        }

        // Restore target project
        if frameworkMapping.nestedProjectPath != nil {
            logger.info("Restoring target project from backup...")
            do {
                try backupManager.restoreLatestBackup(for: "\(frameworkMapping.id)-target")
                logger.info("Target project restored successfully")
            } catch BackupError.noBackupFound {
                logger.warning("No backup found for target project. Removing nested project reference manually...")
                let targetModifier = try ProjectModifier(projectPath: projects.targetProjectPath)
                try targetModifier.removeNestedProject(at: frameworkMapping.nestedProjectPath!)
                try targetModifier.save()
                logger.info("Nested project reference removed")
            }
        }

        // Clear linking state
        try LinkingState.clear(at: projects.basePath)

        logger.info("")
        logger.success("Framework linking disabled for '\(mapping)'!")
        logger.info("")
        logger.info("The projects have been restored to their original configuration.")
    }
}
