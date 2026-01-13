import ArgumentParser

@main
struct LinkFrameworkCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "link-framework-cli",
        abstract: "Automate local framework debugging setup for iOS projects",
        version: "1.0.0",
        subcommands: [EnableCommand.self, DisableCommand.self, StatusCommand.self],
        defaultSubcommand: StatusCommand.self
    )
}

// Explicit entry point not needed - @main handles this
