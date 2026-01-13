import ArgumentParser

struct LinkCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "link",
        abstract: "Manage local framework linking for debugging",
        subcommands: [EnableCommand.self, DisableCommand.self, StatusCommand.self],
        defaultSubcommand: StatusCommand.self
    )
}
