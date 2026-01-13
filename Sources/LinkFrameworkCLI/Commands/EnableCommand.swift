import ArgumentParser
import Foundation

struct EnableCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "enable",
        abstract: "Enable local framework linking for debugging"
    )

    @Argument(help: "Framework mapping to enable (e.g., 'subscription')")
    var mapping: String

    @Option(name: .shortAndLong, help: "Path to the project directory")
    var path: String?

    @Flag(name: .shortAndLong, help: "Dry run - show changes without applying")
    var dryRun: Bool = false

    @Flag(name: .shortAndLong, help: "Verbose output")
    var verbose: Bool = false

    mutating func run() async throws {
        let logger = Logger(verbose: verbose)

        logger.info("Enabling framework linking for '\(mapping)'...")

        guard let frameworkMapping = FrameworkMappingRegistry.shared.mapping(for: mapping) else {
            throw LinkFrameworkError.unknownMapping(mapping, available: FrameworkMappingRegistry.shared.availableMappings)
        }

        let basePath = path ?? FileManager.default.currentDirectoryPath
        let locator = ProjectLocator()

        logger.verbose("Looking for projects from: \(basePath)")

        let projects = try locator.locateProjects(from: basePath, mapping: frameworkMapping)

        logger.info("Found projects:")
        logger.info("  Source: \(projects.sourceProjectPath)")
        logger.info("  Target: \(projects.targetProjectPath)")

        if dryRun {
            logger.info("")
            logger.info("[DRY RUN] Would perform the following changes:")
            logger.info("")
            logger.info("1. Remap framework paths in \(frameworkMapping.sourceProject.name):")
            for remapping in frameworkMapping.frameworkRemappings {
                logger.info("   - \(remapping.frameworkName)")
                logger.info("     FROM: \(remapping.originalPath)")
                logger.info("     TO:   \(remapping.linkedPath)")
            }
            logger.info("")
            if let nestedPath = frameworkMapping.nestedProjectPath {
                logger.info("2. Add nested project reference in \(frameworkMapping.targetProject.name):")
                logger.info("   - \(nestedPath)")
            }
            return
        }

        let backupManager = BackupManager()

        // Backup and modify source project
        logger.info("")
        logger.info("Backing up source project...")
        let sourceBackup = try backupManager.createBackup(
            of: projects.sourceProjectPath,
            mappingId: frameworkMapping.id
        )
        logger.verbose("Backup created at: \(sourceBackup)")

        logger.info("Remapping framework paths...")
        let sourceModifier = try ProjectModifier(projectPath: projects.sourceProjectPath)
        try sourceModifier.remapFrameworks(frameworkMapping.frameworkRemappings, toLinked: true)
        try sourceModifier.save()
        logger.info("Source project updated successfully")

        // Backup and modify target project (add nested project reference)
        if let nestedPath = frameworkMapping.nestedProjectPath {
            logger.info("")
            logger.info("Backing up target project...")
            let targetBackup = try backupManager.createBackup(
                of: projects.targetProjectPath,
                mappingId: "\(frameworkMapping.id)-target"
            )
            logger.verbose("Backup created at: \(targetBackup)")

            logger.info("Adding nested project reference...")
            let targetModifier = try ProjectModifier(projectPath: projects.targetProjectPath)
            try targetModifier.addNestedProject(at: nestedPath)
            try targetModifier.save()
            logger.info("Target project updated successfully")
        }

        // Save linking state
        try LinkingState.write(enabled: true, mapping: frameworkMapping.id, at: projects.basePath)

        logger.info("")
        logger.success("Framework linking enabled for '\(mapping)'!")
        logger.info("")
        logger.info("Next steps:")
        logger.info("  1. Open \(frameworkMapping.targetProject.name) in Xcode")
        logger.info("  2. The \(frameworkMapping.sourceProject.name) project should appear in the navigator")
        logger.info("  3. You can now set breakpoints and debug the framework source")
    }
}
