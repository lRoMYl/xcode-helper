import ArgumentParser
import Foundation

struct BrandingCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dh-branding",
        abstract: "Configure project branding and environment interactively"
    )

    @Option(name: .long, help: "Path to the project directory containing bootstrap.sh")
    var path: String?

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
        // Select brand
        let brandMenu = TerminalMenu(
            title: "Select Brand",
            options: Self.brands,
            allowCustomInput: true
        )

        guard let brand = brandMenu.run() else {
            print("Cancelled.")
            return
        }

        // Select environment
        let envMenu = TerminalMenu(
            title: "Select Environment",
            options: Self.environments,
            allowCustomInput: true
        )

        guard let environment = envMenu.run() else {
            print("Cancelled.")
            return
        }

        print("Selected: brand=\(brand), environment=\(environment)")
        print("Executing bootstrap script...")

        try await executeBootstrap(projectPath: projectPath, brand: brand, environment: environment)
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
