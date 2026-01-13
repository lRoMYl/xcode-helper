import ArgumentParser

@main
struct XCodeHelper: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "xcode-helper",
        abstract: "Helper tools for Xcode project management",
        version: "1.0.0",
        subcommands: [LinkCommand.self]
    )
}
