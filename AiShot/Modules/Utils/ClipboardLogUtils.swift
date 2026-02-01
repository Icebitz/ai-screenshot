import AppKit
import Foundation
import UniformTypeIdentifiers

func makeClipboardLogEntry(from pasteboard: NSPasteboard, source: String) -> ClipboardLogEntry {
    let types = pasteboard.types?.map { $0.rawValue } ?? []
    let stringPreview = clipboardPreview(pasteboard.string(forType: .string))
    let fileURLs = clipboardFileURLs(from: pasteboard)
    let hasImage = pasteboard.canReadObject(forClasses: [NSImage.self], options: nil) ||
        pasteboard.canReadItem(withDataConformingToTypes: [
            UTType.png.identifier,
            UTType.jpeg.identifier,
            UTType.tiff.identifier
        ])
    return ClipboardLogEntry(
        timestamp: clipboardTimestampNow(),
        source: source,
        types: types,
        stringPreview: stringPreview,
        fileURLs: fileURLs,
        hasImage: hasImage
    )
}

private func clipboardTimestampNow() -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: Date())
}

private func clipboardPreview(_ text: String?, limit: Int = 200) -> String? {
    guard let text, !text.isEmpty else { return nil }
    let singleLine = text
        .replacingOccurrences(of: "\r\n", with: " ")
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "\r", with: " ")
    if singleLine.count <= limit {
        return singleLine
    }
    let index = singleLine.index(singleLine.startIndex, offsetBy: limit)
    return String(singleLine[..<index]) + "…"
}

private func clipboardFileURLs(from pasteboard: NSPasteboard) -> [String]? {
    let options: [NSPasteboard.ReadingOptionKey: Any] = [
        .urlReadingFileURLsOnly: true
    ]
    guard let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
          !objects.isEmpty else { return nil }
    return objects.map { $0.path }
}
