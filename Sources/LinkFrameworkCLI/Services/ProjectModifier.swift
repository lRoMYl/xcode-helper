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

    /// Remove nested project reference from target project
    func removeNestedProject(at relativePath: String) throws {
        let pbxproj = xcodeProj.pbxproj

        guard let fileRef = pbxproj.fileReferences.first(where: { $0.path == relativePath }) else {
            // Already removed, nothing to do
            return
        }

        // Remove from parent groups
        for group in pbxproj.groups {
            group.children.removeAll { element in
                if let ref = element as? PBXFileReference {
                    return ref.path == relativePath
                }
                return false
            }
        }

        // Delete the file reference
        pbxproj.delete(object: fileRef)
    }

    /// Save changes to disk
    func save() throws {
        try xcodeProj.write(path: projectPath)
    }
}
