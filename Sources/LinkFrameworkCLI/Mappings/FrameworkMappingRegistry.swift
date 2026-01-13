import Foundation

/// Registry of all available framework mappings
final class FrameworkMappingRegistry: Sendable {
    static let shared = FrameworkMappingRegistry()

    private let mappings: [String: FrameworkMapping] = [
        "subscription": .subscription,
        // Add more mappings here as needed
    ]

    private init() {}

    /// Get a mapping by ID
    func mapping(for id: String) -> FrameworkMapping? {
        mappings[id]
    }

    /// Get all available mapping IDs
    var availableMappings: [String] {
        Array(mappings.keys).sorted()
    }
}
