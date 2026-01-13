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
            if let targetFramework = frameworkMapping.targetFramework {
                logger.info("2. In \(frameworkMapping.targetProject.name):")
                logger.info("   - Remove: \(targetFramework.frameworkName)")
                logger.info("   - Add: \(targetFramework.nestedProjectPath)")
            } else if let nestedPath = frameworkMapping.nestedProjectPath {
                logger.info("2. Add nested project reference in \(frameworkMapping.targetProject.name):")
                logger.info("   - \(nestedPath)")
            }
            return
        }

        let backupManager = BackupManager()

        // Backup source project (for rollback on failure)
        logger.info("")
        logger.info("Creating backup for rollback...")
        let sourceBackup = try backupManager.createBackup(
            of: projects.sourceProjectPath,
            mappingId: frameworkMapping.id
        )
        logger.verbose("Source backup at: \(sourceBackup)")

        // Modify source project - remap frameworks
        logger.info("Remapping framework paths in source project...")
        let sourceModifier = try ProjectModifier(projectPath: projects.sourceProjectPath)
        try sourceModifier.remapFrameworks(frameworkMapping.frameworkRemappings, toLinked: true)
        try sourceModifier.save()
        logger.info("Source project updated successfully")

        // Modify target project - swap xcframework with xcodeproj
        var savedXCFrameworkInfo: SavedXCFrameworkInfo?

        if let targetFramework = frameworkMapping.targetFramework {
            logger.info("")
            logger.info("Modifying target project...")

            // Backup target project (for rollback on failure)
            let targetBackup = try backupManager.createBackup(
                of: projects.targetProjectPath,
                mappingId: "\(frameworkMapping.id)-target"
            )
            logger.verbose("Target backup at: \(targetBackup)")

            let targetModifier = try ProjectModifier(projectPath: projects.targetProjectPath)

            // Replace xcframework with xcodeproj
            logger.info("Replacing \(targetFramework.frameworkName) with \(targetFramework.nestedProjectPath)...")
            savedXCFrameworkInfo = try targetModifier.replaceXCFrameworkWithXcodeproj(
                frameworkName: targetFramework.frameworkName,
                frameworkPath: targetFramework.frameworkPath,
                xcodeprojPath: targetFramework.nestedProjectPath,
                productName: targetFramework.productName
            )

            try targetModifier.save()
            logger.info("Target project updated successfully")
        } else if let nestedPath = frameworkMapping.nestedProjectPath {
            // Fallback to just adding nested project (legacy behavior)
            logger.info("")
            logger.info("Adding nested project reference...")
            let targetModifier = try ProjectModifier(projectPath: projects.targetProjectPath)
            try targetModifier.addNestedProject(at: nestedPath)
            try targetModifier.save()
            logger.info("Target project updated successfully")
        }

        // Save linking state with xcframework info for restoration
        try LinkingState.write(
            enabled: true,
            mapping: frameworkMapping.id,
            savedXCFrameworkInfo: savedXCFrameworkInfo,
            at: projects.basePath
        )

        logger.info("")
        logger.success("Framework linking enabled for '\(mapping)'!")
        logger.info("")
        logger.info("Next steps:")
        logger.info("  1. Open \(frameworkMapping.targetProject.name) in Xcode")
        logger.info("  2. The \(frameworkMapping.sourceProject.name) project should appear in the navigator")
        logger.info("  3. You can now set breakpoints and debug the framework source")
    }
}
