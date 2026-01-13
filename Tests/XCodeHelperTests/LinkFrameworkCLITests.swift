import Testing
@testable import XCodeHelper

@Suite("FrameworkMapping Tests")
struct FrameworkMappingTests {
    @Test("Subscription mapping has correct ID")
    func subscriptionMappingId() {
        let mapping = FrameworkMapping.subscription
        #expect(mapping.id == "subscription")
    }

    @Test("Subscription mapping has 10 framework remappings")
    func subscriptionMappingFrameworkCount() {
        let mapping = FrameworkMapping.subscription
        #expect(mapping.frameworkRemappings.count == 10)
    }

    @Test("Registry returns subscription mapping")
    func registryReturnsSubscription() {
        let mapping = FrameworkMappingRegistry.shared.mapping(for: "subscription")
        #expect(mapping != nil)
        #expect(mapping?.id == "subscription")
    }

    @Test("Registry returns nil for unknown mapping")
    func registryReturnsNilForUnknown() {
        let mapping = FrameworkMappingRegistry.shared.mapping(for: "unknown")
        #expect(mapping == nil)
    }
}
