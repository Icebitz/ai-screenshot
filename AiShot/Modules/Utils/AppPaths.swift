import Foundation

enum AppPaths {
    private static let appFolderName = "AiShot"
    private static let cacheFolderName = "cache"

    static func ensureCacheStructure() {
        guard let root = cacheRootURL() else { return }
        let directories = [
            root,
            liveDirectoryURL(),
            liveAutoDirectoryURL(),
            liveClipDirectoryURL()
        ].compactMap { $0 }
        directories.forEach { createDirectoryIfNeeded(at: $0) }
    }

    static func baseDirectoryURL() -> URL? {
        return cacheRootURL()
    }

    static func cacheRootURL() -> URL? {
        let fileManager = FileManager.default
        guard let cachesRoot = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let appDirectory = cachesRoot.appendingPathComponent(appFolderName, isDirectory: true)
        let cacheDirectory = appDirectory.appendingPathComponent(cacheFolderName, isDirectory: true)
        createDirectoryIfNeeded(at: cacheDirectory)
        return cacheDirectory
    }

    static func liveDirectoryURL() -> URL? {
        return cacheRootURL()?.appendingPathComponent("live", isDirectory: true)
    }

    static func liveAutoDirectoryURL() -> URL? {
        return liveDirectoryURL()?.appendingPathComponent("auto", isDirectory: true)
    }

    static func liveClipDirectoryURL() -> URL? {
        return liveDirectoryURL()?.appendingPathComponent("clip", isDirectory: true)
    }

    static func deviceIdURL() -> URL? {
        return cacheRootURL()?.appendingPathComponent("device_id", isDirectory: false)
    }

    static func clipboardLogURL() -> URL? {
        return liveDirectoryURL()?.appendingPathComponent("clipboard.log", isDirectory: false)
    }

    private static func createDirectoryIfNeeded(at url: URL) {
        do {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            print("Failed to create directory: \(url.path), error: \(error)")
        }
    }
}
