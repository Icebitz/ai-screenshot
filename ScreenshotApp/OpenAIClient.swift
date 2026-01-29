import Foundation
import ImageIO

enum OpenAIClientError: Error {
    case invalidResponse
    case requestFailed(statusCode: Int)
    case missingImageData
    case decodeFailed
}

struct OpenAIClient {
    private static let endpoint = URL(string: "https://api.openai.com/v1/images/edits")!
    private static let model = "gpt-image-1"
    private static let logFilename = "openai.log"

    static func editImage(apiKey: String, prompt: String, imageData: Data) async throws -> CGImage {
        writeLog("request started (bytes=\(imageData.count))")
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func append(_ string: String) {
            guard let data = string.data(using: .utf8) else { return }
            body.append(data)
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        append("\(model)\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n")
        append("\(prompt)\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"image\"; filename=\"selection.png\"\r\n")
        append("Content-Type: image/png\r\n\r\n")
        body.append(imageData)
        append("\r\n")

        append("--\(boundary)--\r\n")
        request.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            writeLog("request error: \(error)")
            throw error
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            writeLog("invalid response")
            throw OpenAIClientError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let bodyPreview = String(data: data.prefix(2048), encoding: .utf8) ?? ""
            writeLog("request failed status=\(httpResponse.statusCode) body=\(bodyPreview)")
            throw OpenAIClientError.requestFailed(statusCode: httpResponse.statusCode)
        }
        writeLog("response ok (bytes=\(data.count))")

        let decoded = try JSONDecoder().decode(OpenAIImagesResponse.self, from: data)
        guard let b64 = decoded.data.first?.b64_json,
              let imageData = Data(base64Encoded: b64) else {
            writeLog("missing image data in response")
            throw OpenAIClientError.missingImageData
        }
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            writeLog("decode failed")
            throw OpenAIClientError.decodeFailed
        }
        writeLog("decode ok (w=\(image.width) h=\(image.height))")
        return image
    }

    private static func writeLog(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        let url = logFileURL()
        if !FileManager.default.fileExists(atPath: url.path) {
            try? data.write(to: url)
            return
        }
        if let handle = try? FileHandle(forWritingTo: url) {
            do {
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } catch {
                try? handle.close()
            }
        }
    }

    static func logFileURL() -> URL {
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        let bundleId = Bundle.main.bundleIdentifier ?? "ScreenshotApp"
        let directory = cacheDirectory?.appendingPathComponent(bundleId, isDirectory: true)
        if let directory {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory.appendingPathComponent(logFilename)
        }
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(logFilename)
    }
}

private struct OpenAIImagesResponse: Decodable {
    let data: [OpenAIImageData]
}

private struct OpenAIImageData: Decodable {
    let b64_json: String?
}
