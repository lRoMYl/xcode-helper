import ArgumentParser
import Foundation

struct BrandingCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dh-branding",
        abstract: "Configure project branding and environment",
        discussion: """
            Configures the branding and environment for a DH Verticals project.

            Interactive mode (default):
              $ xcode-helper dh-branding
              Shows interactive menus for brand and environment selection.

            Partial automation:
              $ xcode-helper dh-branding --brand foodpanda
              Skips brand menu, shows environment menu.

            Full automation:
              $ xcode-helper dh-branding --brand foodpanda --environment staging
              Skips both menus and runs bootstrap directly.

            Available brands: foodpanda, foodora, yemeksepeti
            Available environments: staging, production
            Custom values are also supported.
            """
    )

    @Option(name: .long, help: "Path to the project directory containing bootstrap.sh")
    var path: String?

    @Option(name: .long, help: "Brand to configure (e.g., foodpanda, foodora, yemeksepeti)")
    var brand: String?

    @Option(name: .long, help: "Environment to use (e.g., staging, production)")
    var environment: String?

    // Predefined brand options
    private static let brands = [
        "foodpanda",
        "foodora",
        "yemeksepeti"
    ]

    // Predefined environment options
    private static let environments = [
        "staging",
        "production"
    ]

    mutating func run() async throws {
        // Discover project path
        let projectPath = try discoverProjectPath()
        print("Using project: \(projectPath)")

        // Determine brand (from CLI arg or interactive menu)
        let selectedBrand: String
        if let providedBrand = brand {
            // Validate and use provided brand
            if Self.brands.contains(providedBrand) {
                print("Using brand: \(providedBrand)")
                selectedBrand = providedBrand
            } else {
                // Allow custom values with warning
                print("Warning: '\(providedBrand)' is not a standard brand.")
                print("Standard brands: \(Self.brands.joined(separator: ", "))")
                print("Using custom brand: \(providedBrand)")
                selectedBrand = providedBrand
            }
        } else {
            // Show interactive menu
            let brandMenu = TerminalMenu(
                title: "Select Brand",
                options: Self.brands,
                allowCustomInput: true
            )

            guard let menuBrand = brandMenu.run() else {
                print("Cancelled.")
                return
            }
            selectedBrand = menuBrand
        }

        // Determine environment (from CLI arg or interactive menu)
        let selectedEnvironment: String
        if let providedEnvironment = environment {
            // Validate and use provided environment
            if Self.environments.contains(providedEnvironment) {
                print("Using environment: \(providedEnvironment)")
                selectedEnvironment = providedEnvironment
            } else {
                // Allow custom values with warning
                print("Warning: '\(providedEnvironment)' is not a standard environment.")
                print("Standard environments: \(Self.environments.joined(separator: ", "))")
                print("Using custom environment: \(providedEnvironment)")
                selectedEnvironment = providedEnvironment
            }
        } else {
            // Show interactive menu
            let envMenu = TerminalMenu(
                title: "Select Environment",
                options: Self.environments,
                allowCustomInput: true
            )

            guard let menuEnvironment = envMenu.run() else {
                print("Cancelled.")
                return
            }
            selectedEnvironment = menuEnvironment
        }

        print("Selected: brand=\(selectedBrand), environment=\(selectedEnvironment)")
        print("Executing bootstrap script...")

        try await executeBootstrap(projectPath: projectPath, brand: selectedBrand, environment: selectedEnvironment)
    }

    /// Discovers the project path containing bootstrap.sh
    private func discoverProjectPath() throws -> String {
        let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath

        // 1. If --path is provided, use it
        if let customPath = path {
            let expandedPath = NSString(string: customPath).expandingTildeInPath
            let bootstrapPath = (expandedPath as NSString).appendingPathComponent("bootstrap.sh")
            if fileManager.fileExists(atPath: bootstrapPath) {
                return expandedPath
            }
            throw BrandingError.bootstrapNotFound(customPath)
        }

        // 2. Check current directory
        let currentBootstrap = (currentDir as NSString).appendingPathComponent("bootstrap.sh")
        if fileManager.fileExists(atPath: currentBootstrap) {
            return currentDir
        }

        // 3. Check pd-mob-b2c-ios subdirectory
        let subdir = (currentDir as NSString).appendingPathComponent("pd-mob-b2c-ios")
        let subdirBootstrap = (subdir as NSString).appendingPathComponent("bootstrap.sh")
        if fileManager.fileExists(atPath: subdirBootstrap) {
            return subdir
        }

        throw BrandingError.bootstrapNotFound("current directory or pd-mob-b2c-ios/")
    }

    private func executeBootstrap(projectPath: String, brand: String, environment: String) async throws {
        let script = """
        on run
            set projectPath to "\(projectPath)"
            set brand to "\(brand)"
            set env to "\(environment)"

            -- Try opening iTerm (no System Events needed)
            set use_iTerm to true
            try
                tell application "iTerm" to version
            on error
                set use_iTerm to false
            end try

            if use_iTerm then
                -- iTerm PATH EXECUTION
                tell application "iTerm"
                    activate
                    if (count of windows) = 0 then
                        create window with default profile
                    end if

                    tell current session of current window
                        write text "cd " & quoted form of projectPath
                        write text "./bootstrap.sh prepare_branding --brand=" & brand & " --environment=" & env
                        write text "./bootstrap.sh setup_project"
                    end tell
                end tell

            else
                -- Terminal PATH EXECUTION
                tell application "Terminal"
                    activate
                    if not (exists window 1) then
                        do script ""
                    end if

                    tell window 1
                        do script "cd " & quoted form of projectPath in selected tab
                        do script "./bootstrap.sh prepare_branding --brand=" & brand & " --environment=" & env in selected tab
                        do script "./bootstrap.sh setup_project" in selected tab
                    end tell
                end tell
            end if
        end run
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw BrandingError.scriptFailed(errorMessage)
        }

        print("Bootstrap script launched successfully!")
    }
}

enum BrandingError: Error, CustomStringConvertible {
    case scriptFailed(String)
    case bootstrapNotFound(String)

    var description: String {
        switch self {
        case .scriptFailed(let message):
            return "AppleScript execution failed: \(message)"
        case .bootstrapNotFound(let location):
            return "bootstrap.sh not found in \(location). Use --path to specify the project directory."
        }
    }
}
