import ArgumentParser
import Foundation

struct StatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show current framework linking status"
    )

    @Option(name: .shortAndLong, help: "Path to the project directory")
    var path: String?

    @Flag(name: .shortAndLong, help: "Verbose output")
    var verbose: Bool = false

    mutating func run() async throws {
        let logger = Logger(verbose: verbose)

        let basePath = path ?? FileManager.default.currentDirectoryPath

        logger.info("Checking framework linking status...")
        logger.info("")

        // Check for state file
        if let state = try? LinkingState.read(from: basePath) {
            logger.info("Status: ENABLED")
            logger.info("  Mapping: \(state.mapping)")
            logger.info("  Enabled at: \(state.timestamp)")
            logger.info("")
            logger.info("To disable, run:")
            logger.info("  link-framework-cli disable \(state.mapping)")
        } else {
            logger.info("Status: DISABLED")
            logger.info("")
            logger.info("Available mappings:")
            for mappingId in FrameworkMappingRegistry.shared.availableMappings {
                if let mapping = FrameworkMappingRegistry.shared.mapping(for: mappingId) {
                    logger.info("  - \(mappingId): \(mapping.displayName)")
                }
            }
            logger.info("")
            logger.info("To enable framework linking, run:")
            logger.info("  link-framework-cli enable <mapping>")
        }
    }
}
