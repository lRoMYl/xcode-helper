import Foundation

extension FrameworkMapping {
    /// Mapping for pd-mob-subscription-ios framework
    static let subscription = FrameworkMapping(
        id: "subscription",
        displayName: "pd-mob-subscription-ios",
        sourceProject: ProjectReference(
            name: "pd-mob-subscription-ios",
            projectPath: "Subscription/Subscription.xcodeproj",
            expectedDirectory: "pd-mob-subscription-ios"
        ),
        targetProject: ProjectReference(
            name: "pd-mob-b2c-ios",
            projectPath: "Volo.xcodeproj",
            expectedDirectory: "pd-mob-b2c-ios"
        ),
        frameworkRemappings: [
            FrameworkRemapping(
                frameworkName: "ApiClient.xcframework",
                originalPath: "../Carthage/Build/ApiClient.xcframework",
                linkedPath: "../../pd-mob-b2c-ios/Carthage/Build/ApiClient.xcframework"
            ),
            FrameworkRemapping(
                frameworkName: "RxCocoa.xcframework",
                originalPath: "../Carthage/Build/RxCocoa.xcframework",
                linkedPath: "../../pd-mob-b2c-ios/Carthage/Build/RxCocoa.xcframework"
            ),
            FrameworkRemapping(
                frameworkName: "RxRelay.xcframework",
                originalPath: "../Carthage/Build/RxRelay.xcframework",
                linkedPath: "../../pd-mob-b2c-ios/Carthage/Build/RxRelay.xcframework"
            ),
            FrameworkRemapping(
                frameworkName: "RxSwift.xcframework",
                originalPath: "../Carthage/Build/RxSwift.xcframework",
                linkedPath: "../../pd-mob-b2c-ios/Carthage/Build/RxSwift.xcframework"
            ),
            FrameworkRemapping(
                frameworkName: "SDWebImage.xcframework",
                originalPath: "../Carthage/Build/SDWebImage.xcframework",
                linkedPath: "../../pd-mob-b2c-ios/Carthage/Build/SDWebImage.xcframework"
            ),
            FrameworkRemapping(
                frameworkName: "Bento.xcframework",
                originalPath: "../Carthage/Build/Bento.xcframework",
                linkedPath: "../../pd-mob-b2c-ios/Carthage/Build/Bento.xcframework"
            ),
            FrameworkRemapping(
                frameworkName: "Lottie.xcframework",
                originalPath: "../Carthage/Build/Lottie.xcframework",
                linkedPath: "../../pd-mob-b2c-ios/Carthage/Build/Lottie.xcframework"
            ),
            FrameworkRemapping(
                frameworkName: "UnifiedLogging.xcframework",
                originalPath: "../Carthage/Build/UnifiedLogging.xcframework",
                linkedPath: "../../pd-mob-b2c-ios/Carthage/Build/UnifiedLogging.xcframework"
            ),
            FrameworkRemapping(
                frameworkName: "Apollo.xcframework",
                originalPath: "../Carthage/Checkouts/apollo-ios-xcframework/xcframeworks/Apollo.xcframework",
                linkedPath: "../../pd-mob-b2c-ios/Carthage/Checkouts/apollo-ios-xcframework/xcframeworks/Apollo.xcframework"
            ),
            FrameworkRemapping(
                frameworkName: "ApolloAPI.xcframework",
                originalPath: "../Carthage/Checkouts/apollo-ios-xcframework/xcframeworks/ApolloAPI.xcframework",
                linkedPath: "../../pd-mob-b2c-ios/Carthage/Checkouts/apollo-ios-xcframework/xcframeworks/ApolloAPI.xcframework"
            ),
        ],
        nestedProjectPath: "../pd-mob-subscription-ios/Subscription/Subscription.xcodeproj",
        targetFramework: TargetFrameworkInfo(
            frameworkName: "Subscription.xcframework",
            frameworkPath: "Carthage/Build/Subscription.xcframework",
            nestedProjectPath: "../pd-mob-subscription-ios/Subscription/Subscription.xcodeproj",
            productName: "Subscription"
        )
    )
}
