import Foundation

enum AppPaths {
    static func baseDirectoryURL() -> URL? {
        let fileManager = FileManager.default
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let bundleId = Bundle.main.bundleIdentifier ?? "AiShot"
        let directory = baseDirectory?.appendingPathComponent(bundleId, isDirectory: true)
        if let directory {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        }
        return nil
    }
}
