import Foundation

enum AppPaths {
    private static let appFolderName = "AiShot"
    private static let cacheFolderName = "cache"
    private static let tempFolderName = "temp"
    private static let tempLimitSizeBytes: Int64 = 10 * 1_048_576
    private static let tempArchiveDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()

    static func ensureCacheStructure() {
        guard let root = cacheRootURL() else { return }
        let directories = [
            root,
            liveDirectoryURL(),
            liveAutoDirectoryURL(),
            liveClipDirectoryURL(),
            tempDirectoryURL(),
            tempAutoDirectoryURL(),
            tempClipDirectoryURL()
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

    static func tempDirectoryURL() -> URL? {
        return cacheRootURL()?.appendingPathComponent(tempFolderName, isDirectory: true)
    }

    static func tempAutoDirectoryURL() -> URL? {
        return tempDirectoryURL()?.appendingPathComponent("auto", isDirectory: true)
    }

    static func tempClipDirectoryURL() -> URL? {
        return tempDirectoryURL()?.appendingPathComponent("clip", isDirectory: true)
    }

    static func deviceIdURL() -> URL? {
        return cacheRootURL()?.appendingPathComponent("device_id", isDirectory: false)
    }

    static func clipboardLogURL() -> URL? {
        return liveDirectoryURL()?.appendingPathComponent("data.log", isDirectory: false)
    }

    static func tempClipboardLogURL() -> URL? {
        return tempDirectoryURL()?.appendingPathComponent("data.log", isDirectory: false)
    }

    static func maintainTempCache() {
        guard let liveRoot = liveDirectoryURL(),
              let tempRoot = tempDirectoryURL() else { return }
        createDirectoryIfNeeded(at: tempRoot)
        if let tempAuto = tempAutoDirectoryURL() {
            createDirectoryIfNeeded(at: tempAuto)
        }
        if let tempClip = tempClipDirectoryURL() {
            createDirectoryIfNeeded(at: tempClip)
        }
        let currentTempSize = directorySizeBytes(at: tempRoot)
        if currentTempSize > tempLimitSizeBytes {
            archiveTempCacheIfNeeded()
            return
        }
        let filesToMove = collectLiveFilesSorted(liveRoot: liveRoot)
        var totalSize = currentTempSize
        let fileManager = FileManager.default
        for fileURL in filesToMove {
            guard let relativePath = fileURL.pathComponents.dropFirst(liveRoot.pathComponents.count).joined(separator: "/").nilIfEmpty else {
                continue
            }
            let destinationURL = tempRoot.appendingPathComponent(relativePath)
            createDirectoryIfNeeded(at: destinationURL.deletingLastPathComponent())
            do {
                let size = fileSizeBytes(at: fileURL)
                try fileManager.moveItem(at: fileURL, to: destinationURL)
                totalSize += size
                if totalSize > tempLimitSizeBytes { break }
            } catch {
                // Best-effort; ignore move errors.
            }
        }
        archiveTempCacheIfNeeded()
    }

    static func archiveTempCacheIfNeeded() {
        guard let tempRoot = tempDirectoryURL(),
              let cacheRoot = cacheRootURL() else { return }
        let currentTempSize = directorySizeBytes(at: tempRoot)
        guard currentTempSize >= tempLimitSizeBytes else { return }
        let timestamp = tempArchiveDateFormatter.string(from: Date())
        let zipURL = cacheRoot.appendingPathComponent("temp-\(timestamp).zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", zipURL.path, tempRoot.lastPathComponent]
        process.currentDirectoryURL = tempRoot.deletingLastPathComponent()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return
        }
        guard process.terminationStatus == 0 else { return }
        clearDirectoryContents(at: tempRoot)
        ensureCacheStructure()
    }

    static func copyLiveLogToTempIfNeeded() {
        guard let liveLog = clipboardLogURL(),
              let tempLog = tempClipboardLogURL() else { return }
        let fileManager = FileManager.default
        let liveDate = (try? liveLog.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        let tempDate = (try? tempLog.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        guard let liveDate else { return }
        if let tempDate, tempDate >= liveDate { return }
        createDirectoryIfNeeded(at: tempLog.deletingLastPathComponent())
        if fileManager.fileExists(atPath: tempLog.path) {
            try? fileManager.removeItem(at: tempLog)
        }
        try? fileManager.copyItem(at: liveLog, to: tempLog)
    }

    private static func collectLiveFilesSorted(liveRoot: URL) -> [URL] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: liveRoot,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var files: [(url: URL, date: Date)] = []
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
            if values?.isDirectory == true { continue }
            let date = values?.contentModificationDate ?? Date.distantPast
            files.append((url: url, date: date))
        }
        return files.sorted { $0.date < $1.date }.map { $0.url }
    }

    private static func directorySizeBytes(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            if values?.isDirectory == true { continue }
            total += Int64(values?.fileSize ?? 0)
        }
        return total
    }

    private static func fileSizeBytes(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }

    private static func clearDirectoryContents(at url: URL) {
        let fileManager = FileManager.default
        guard let items = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else {
            return
        }
        for item in items {
            try? fileManager.removeItem(at: item)
        }
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
