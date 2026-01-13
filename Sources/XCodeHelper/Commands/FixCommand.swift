import ArgumentParser
import Foundation

struct FixCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "fix",
        abstract: "Attempt to fix a corrupted project by regenerating it (requires Tuist or XcodeGen)"
    )

    @Argument(help: "Framework mapping to fix (optional - auto-detects from saved state or current directory)")
    var mapping: String?

    @Option(name: .shortAndLong, help: "Path to the project directory")
    var path: String?

    @Flag(name: .shortAndLong, help: "Verbose output")
    var verbose: Bool = false

    enum ProjectGenerator {
        case tuist
        case xcodegen
        case none
    }

    mutating func run() async throws {
        let logger = Logger(verbose: verbose)
        let basePath = path ?? FileManager.default.currentDirectoryPath

        // Resolve project path: from mapping, saved state, or auto-detect
        let projectPath = try resolveProjectPath(basePath: basePath, logger: logger)
        let projectDir = URL(fileURLWithPath: projectPath).deletingLastPathComponent().path

        logger.info("Attempting to fix project at: \(projectPath)")

        // Check for project generator tools
        let projectGenerator = detectProjectGenerator(in: projectDir)

        switch projectGenerator {
        case .tuist:
            logger.info("Detected Tuist-managed project")
            try await regenerateWithTuist(in: projectDir, logger: logger)
        case .xcodegen:
            logger.info("Detected XcodeGen-managed project")
            try await regenerateWithXcodeGen(in: projectDir, logger: logger)
        case .none:
            throw LinkFrameworkError.cannotFix(
                "Unable to automatically fix the project.\n" +
                "No project generator detected (looked for Tuist manifest files or project.yml).\n\n" +
                "Manual recovery options:\n" +
                "  1. Restore from backup: cp ~/.xcode-helper/backups/<latest>/project.pbxproj \(projectPath)/\n" +
                "  2. Restore from git: git checkout \(projectPath)/project.pbxproj\n" +
                "  3. Manually fix the project in Xcode"
            )
        }

        logger.success("Project regenerated successfully!")
    }

    private func resolveProjectPath(basePath: String, logger: Logger) throws -> String {
        // Option 1: If mapping is provided, use it
        if let mappingId = mapping {
            guard let frameworkMapping = FrameworkMappingRegistry.shared.mapping(for: mappingId) else {
                throw LinkFrameworkError.unknownMapping(mappingId, available: FrameworkMappingRegistry.shared.availableMappings)
            }
            let locator = ProjectLocator()
            let projects = try locator.locateProjects(from: basePath, mapping: frameworkMapping)
            return projects.targetProjectPath
        }

        // Option 2: Try to read from saved linking state
        if let savedState = try? LinkingState.read(from: basePath),
           let frameworkMapping = FrameworkMappingRegistry.shared.mapping(for: savedState.mapping) {
            logger.verbose("Using mapping '\(savedState.mapping)' from saved state")
            let locator = ProjectLocator()
            let projects = try locator.locateProjects(from: basePath, mapping: frameworkMapping)
            return projects.targetProjectPath
        }

        // Option 3: Auto-detect .xcodeproj in current directory
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(atPath: basePath)
        let xcodeprojs = contents.filter { $0.hasSuffix(".xcodeproj") }

        if xcodeprojs.count == 1 {
            let projectPath = URL(fileURLWithPath: basePath).appendingPathComponent(xcodeprojs[0]).path
            logger.verbose("Auto-detected project: \(projectPath)")
            return projectPath
        } else if xcodeprojs.isEmpty {
            throw LinkFrameworkError.cannotFix(
                "No .xcodeproj found in current directory.\n" +
                "Please specify a mapping: xcode-helper link fix <mapping>\n" +
                "Or run from the project directory."
            )
        } else {
            throw LinkFrameworkError.cannotFix(
                "Multiple .xcodeproj files found: \(xcodeprojs.joined(separator: ", "))\n" +
                "Please specify which mapping to fix: xcode-helper link fix <mapping>"
            )
        }
    }

    private func detectProjectGenerator(in directory: String) -> ProjectGenerator {
        let fileManager = FileManager.default

        // Check for Tuist (Project.swift, Workspace.swift, or Tuist/ directory)
        let tuistMarkers = ["Project.swift", "Workspace.swift", "Tuist"]
        for marker in tuistMarkers {
            let markerPath = URL(fileURLWithPath: directory).appendingPathComponent(marker).path
            if fileManager.fileExists(atPath: markerPath) {
                return .tuist
            }
        }

        // Check for XcodeGen (project.yml, project.yaml, project.json)
        let xcodegenMarkers = ["project.yml", "project.yaml", "project.json"]
        for marker in xcodegenMarkers {
            let markerPath = URL(fileURLWithPath: directory).appendingPathComponent(marker).path
            if fileManager.fileExists(atPath: markerPath) {
                return .xcodegen
            }
        }

        return .none
    }

    private func regenerateWithTuist(in directory: String, logger: Logger) async throws {
        logger.info("Running: tuist generate")
        let result = try await runCommand("tuist", arguments: ["generate"], in: directory)
        if !result.success {
            throw LinkFrameworkError.regenerationFailed("tuist generate failed: \(result.output)")
        }
    }

    private func regenerateWithXcodeGen(in directory: String, logger: Logger) async throws {
        logger.info("Running: xcodegen generate")
        let result = try await runCommand("xcodegen", arguments: ["generate"], in: directory)
        if !result.success {
            throw LinkFrameworkError.regenerationFailed("xcodegen generate failed: \(result.output)")
        }
    }

    private func runCommand(_ command: String, arguments: [String], in directory: String) async throws -> (success: Bool, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments
        process.currentDirectoryURL = URL(fileURLWithPath: directory)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return (process.terminationStatus == 0, output)
    }
}
