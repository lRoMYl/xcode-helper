import Foundation
import PathKit
import XcodeProj

/// Service to modify Xcode project files
final class ProjectModifier {
    private let xcodeProj: XcodeProj
    private let projectPath: Path

    init(projectPath: String) throws {
        self.projectPath = Path(projectPath)
        self.xcodeProj = try XcodeProj(path: self.projectPath)
    }

    /// Remap framework references from original paths to linked paths (or vice versa)
    func remapFrameworks(_ remappings: [FrameworkRemapping], toLinked: Bool) throws {
        let pbxproj = xcodeProj.pbxproj

        for remapping in remappings {
            // Find PBXFileReference entries for this framework
            let fileRefs = pbxproj.fileReferences.filter { fileRef in
                fileRef.name == remapping.frameworkName ||
                fileRef.path?.hasSuffix(remapping.frameworkName) == true
            }

            for fileRef in fileRefs {
                let newPath = toLinked ? remapping.linkedPath : remapping.originalPath
                fileRef.path = newPath
            }
        }
    }

    /// Add nested project reference to target project
    func addNestedProject(at relativePath: String) throws {
        let pbxproj = xcodeProj.pbxproj

        // Check if already added
        let existingRef = pbxproj.fileReferences.first { fileRef in
            fileRef.path == relativePath
        }

        guard existingRef == nil else {
            // Already exists, nothing to do
            return
        }

        // Get the project name from the path
        let projectName = URL(fileURLWithPath: relativePath).lastPathComponent

        // Create new file reference for the nested project
        let fileRef = PBXFileReference(
            sourceTree: .sourceRoot,
            name: projectName,
            lastKnownFileType: "wrapper.pb-project",
            path: relativePath
        )

        pbxproj.add(object: fileRef)

        // Add to main group
        if let mainGroup = pbxproj.projects.first?.mainGroup {
            mainGroup.children.append(fileRef)
        }
    }

    /// Remove nested project reference and all related proxy objects from target project
    func removeNestedProject(at relativePath: String) throws {
        let pbxproj = xcodeProj.pbxproj

        guard let fileRef = pbxproj.fileReferences.first(where: { $0.path == relativePath }) else {
            // Already removed, nothing to do
            return
        }

        // Helper function to check if a proxy references our nested project
        func proxyReferencesProject(_ proxy: PBXContainerItemProxy) -> Bool {
            switch proxy.containerPortal {
            case .fileReference(let ref):
                return ref.uuid == fileRef.uuid
            case .project, .unknownObject:
                return false
            }
        }

        // 1. Remove PBXContainerItemProxy objects that reference this project
        let containerProxies = pbxproj.containerItemProxies.filter { proxyReferencesProject($0) }
        for proxy in containerProxies {
            pbxproj.delete(object: proxy)
        }

        // 2. Remove PBXTargetDependency objects that reference this project
        let dependenciesToRemove = pbxproj.targetDependencies.filter { dep in
            guard let proxy = dep.targetProxy else { return false }
            return proxyReferencesProject(proxy)
        }
        // Remove from target's dependencies array first
        for target in pbxproj.nativeTargets {
            target.dependencies.removeAll { dependency in
                guard let proxy = dependency.targetProxy else { return false }
                return proxyReferencesProject(proxy)
            }
        }
        // Then delete the dependency objects
        for dep in dependenciesToRemove {
            pbxproj.delete(object: dep)
        }

        // 3. Remove PBXReferenceProxy objects that reference products from this project
        let referenceProxies = pbxproj.referenceProxies.filter { proxy in
            guard let remote = proxy.remote else { return false }
            return proxyReferencesProject(remote)
        }
        for proxy in referenceProxies {
            // Remove from groups first
            for group in pbxproj.groups {
                group.children.removeAll { $0.uuid == proxy.uuid }
            }
            pbxproj.delete(object: proxy)
        }

        // 4. Remove the file reference from parent groups
        for group in pbxproj.groups {
            group.children.removeAll { element in
                if let ref = element as? PBXFileReference {
                    return ref.path == relativePath
                }
                return false
            }
        }

        // 5. Delete the file reference
        pbxproj.delete(object: fileRef)
    }

    /// Replace xcframework reference with xcodeproj reference
    /// Returns saved info about the xcframework for later restoration
    func replaceXCFrameworkWithXcodeproj(
        frameworkName: String,
        frameworkPath: String,
        xcodeprojPath: String,
        productName: String
    ) throws -> SavedXCFrameworkInfo? {
        let pbxproj = xcodeProj.pbxproj

        // Find the xcframework file reference
        guard let xcframeworkRef = pbxproj.fileReferences.first(where: { fileRef in
            fileRef.path?.hasSuffix(frameworkName) == true ||
            fileRef.name == frameworkName
        }) else {
            // xcframework not found - might already be using xcodeproj
            return nil
        }

        // Find build files that reference this xcframework
        let buildFiles = pbxproj.buildFiles.filter { buildFile in
            buildFile.file?.uuid == xcframeworkRef.uuid
        }
        let buildFileUUIDs = buildFiles.map { $0.uuid }

        // Find the group containing the xcframework
        var groupUUID: String?
        for group in pbxproj.groups {
            if group.children.contains(where: { $0.uuid == xcframeworkRef.uuid }) {
                groupUUID = group.uuid
                break
            }
        }

        // Save the info for restoration
        let savedInfo = SavedXCFrameworkInfo(
            fileReferenceUUID: xcframeworkRef.uuid,
            buildFileUUIDs: buildFileUUIDs,
            groupUUID: groupUUID,
            originalPath: xcframeworkRef.path ?? frameworkPath,
            originalName: xcframeworkRef.name ?? frameworkName
        )

        // Remove xcframework from groups
        for group in pbxproj.groups {
            group.children.removeAll { $0.uuid == xcframeworkRef.uuid }
        }

        // Remove build files referencing the xcframework
        for buildFile in buildFiles {
            // Remove from build phases
            for target in pbxproj.nativeTargets {
                for buildPhase in target.buildPhases {
                    if let frameworksPhase = buildPhase as? PBXFrameworksBuildPhase {
                        frameworksPhase.files?.removeAll { $0.uuid == buildFile.uuid }
                    }
                    if let copyPhase = buildPhase as? PBXCopyFilesBuildPhase {
                        copyPhase.files?.removeAll { $0.uuid == buildFile.uuid }
                    }
                }
            }
            pbxproj.delete(object: buildFile)
        }

        // Delete the xcframework reference
        pbxproj.delete(object: xcframeworkRef)

        // Add the xcodeproj reference
        try addNestedProject(at: xcodeprojPath)

        // Add the framework product to build phases
        let frameworkProductName = "\(productName).framework"

        // Create file reference for the framework product
        let frameworkRef = PBXFileReference(
            sourceTree: .buildProductsDir,
            name: frameworkProductName,
            lastKnownFileType: "wrapper.framework",
            path: frameworkProductName
        )
        pbxproj.add(object: frameworkRef)

        // Add to Frameworks group
        let frameworksGroup = pbxproj.groups.first { $0.name == "Frameworks" }
        if let group = frameworksGroup {
            group.children.append(frameworkRef)
        } else if let mainGroup = pbxproj.projects.first?.mainGroup {
            mainGroup.children.append(frameworkRef)
        }

        // Create build file and add to frameworks build phase
        let buildFile = PBXBuildFile(file: frameworkRef)
        pbxproj.add(object: buildFile)

        // Add to main target's frameworks build phase
        if let mainTarget = pbxproj.nativeTargets.first(where: { $0.productType == .application }) {
            if let frameworksPhase = mainTarget.buildPhases.first(where: { $0 is PBXFrameworksBuildPhase }) as? PBXFrameworksBuildPhase {
                frameworksPhase.files?.append(buildFile)
            }
        }

        return savedInfo
    }

    /// Replace xcodeproj reference with xcframework reference
    func replaceXcodeprojWithXCFramework(
        xcodeprojPath: String,
        frameworkPath: String,
        frameworkName: String,
        savedInfo: SavedXCFrameworkInfo?
    ) throws {
        let pbxproj = xcodeProj.pbxproj

        // Remove the xcodeproj reference
        try removeNestedProject(at: xcodeprojPath)

        // Remove the framework product reference that was added during enable
        // (e.g., "Subscription.framework" from "Subscription.xcframework")
        let productName = frameworkName.replacingOccurrences(of: ".xcframework", with: "")
        let frameworkProductName = "\(productName).framework"

        if let frameworkProductRef = pbxproj.fileReferences.first(where: { fileRef in
            fileRef.name == frameworkProductName || fileRef.path == frameworkProductName
        }) {
            // Remove from groups
            for group in pbxproj.groups {
                group.children.removeAll { $0.uuid == frameworkProductRef.uuid }
            }

            // Find and remove build files referencing this framework product
            let productBuildFiles = pbxproj.buildFiles.filter { $0.file?.uuid == frameworkProductRef.uuid }
            for buildFile in productBuildFiles {
                // Remove from build phases
                for target in pbxproj.nativeTargets {
                    for buildPhase in target.buildPhases {
                        if let frameworksPhase = buildPhase as? PBXFrameworksBuildPhase {
                            frameworksPhase.files?.removeAll { $0.uuid == buildFile.uuid }
                        }
                        if let copyPhase = buildPhase as? PBXCopyFilesBuildPhase {
                            copyPhase.files?.removeAll { $0.uuid == buildFile.uuid }
                        }
                    }
                }
                pbxproj.delete(object: buildFile)
            }

            // Delete the framework product reference
            pbxproj.delete(object: frameworkProductRef)
        }

        // Check if xcframework already exists
        let existingRef = pbxproj.fileReferences.first { fileRef in
            fileRef.path?.hasSuffix(frameworkName) == true ||
            fileRef.name == frameworkName
        }

        if existingRef != nil {
            // Already exists, nothing more to do
            return
        }

        // Create new xcframework file reference
        let xcframeworkRef = PBXFileReference(
            sourceTree: .group,
            name: savedInfo?.originalName ?? frameworkName,
            lastKnownFileType: "wrapper.xcframework",
            path: savedInfo?.originalPath ?? frameworkPath
        )
        pbxproj.add(object: xcframeworkRef)

        // Add to original group (if saved) or Frameworks group or main group
        if let savedGroupUUID = savedInfo?.groupUUID,
           let originalGroup = pbxproj.groups.first(where: { $0.uuid == savedGroupUUID }) {
            originalGroup.children.append(xcframeworkRef)
        } else {
            // Fallback to Frameworks group or main group
            let frameworksGroup = pbxproj.groups.first { $0.name == "Frameworks" }
            if let group = frameworksGroup {
                group.children.append(xcframeworkRef)
            } else if let mainGroup = pbxproj.projects.first?.mainGroup {
                mainGroup.children.append(xcframeworkRef)
            }
        }

        // Create build file and add to frameworks build phase
        let buildFile = PBXBuildFile(file: xcframeworkRef)
        pbxproj.add(object: buildFile)

        // Add to main target's frameworks build phase
        if let mainTarget = pbxproj.nativeTargets.first(where: { $0.productType == .application }) {
            if let frameworksPhase = mainTarget.buildPhases.first(where: { $0 is PBXFrameworksBuildPhase }) as? PBXFrameworksBuildPhase {
                frameworksPhase.files?.append(buildFile)
            }
        }
    }

    /// Save changes to disk
    func save() throws {
        try xcodeProj.write(path: projectPath)
    }
}
