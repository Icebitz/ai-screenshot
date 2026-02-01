import Foundation
import ImageIO

private let openAIEndpoint = URL(string: "https://api.openai.com/v1/images/edits")!
private let openAILogFilename = "openai.log"
private let openAIRequestTimeout: TimeInterval = 120

func openAIEditImage(
    apiKey: String,
    model: String,
    prompt: String,
    imageData: Data,
    maskData: Data
) async throws -> CGImage {
    let resolvedModel = model.isEmpty ? SettingsStore.defaultAIModel : model
    writeOpenAILog("request started (model=\(resolvedModel) bytes=\(imageData.count) maskBytes=\(maskData.count))")
    let boundary = "Boundary-\(UUID().uuidString)"
    var request = URLRequest(url: openAIEndpoint)
    request.httpMethod = "POST"
    request.timeoutInterval = openAIRequestTimeout
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    var body = Data()
    func append(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        body.append(data)
    }

    append("--\(boundary)\r\n")
    append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
    append("\(resolvedModel)\r\n")

    append("--\(boundary)\r\n")
    append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n")
    append("\(prompt)\r\n")

    append("--\(boundary)\r\n")
    append("Content-Disposition: form-data; name=\"image\"; filename=\"selection.png\"\r\n")
    append("Content-Type: image/png\r\n\r\n")
    body.append(imageData)
    append("\r\n")

    append("--\(boundary)\r\n")
    append("Content-Disposition: form-data; name=\"mask\"; filename=\"mask.png\"\r\n")
    append("Content-Type: image/png\r\n\r\n")
    body.append(maskData)
    append("\r\n")

    append("--\(boundary)--\r\n")
    request.httpBody = body

    let data: Data
    let response: URLResponse
    let session = URLSession(configuration: makeOpenAISessionConfiguration())
    do {
        (data, response) = try await session.data(for: request)
    } catch {
        writeOpenAILog("request error: \(error)")
        throw error
    }
    guard let httpResponse = response as? HTTPURLResponse else {
        writeOpenAILog("invalid response")
        throw OpenAIClientError.invalidResponse
    }
    guard (200...299).contains(httpResponse.statusCode) else {
        let bodyPreview = String(data: data.prefix(2048), encoding: .utf8) ?? ""
        writeOpenAILog("request failed status=\(httpResponse.statusCode) body=\(bodyPreview)")
        throw OpenAIClientError.requestFailed(statusCode: httpResponse.statusCode)
    }
    writeOpenAILog("response ok (bytes=\(data.count))")

    let decoded = try JSONDecoder().decode(OpenAIImagesResponse.self, from: data)
    guard let b64 = decoded.data.first?.b64_json,
          let imageData = Data(base64Encoded: b64) else {
        writeOpenAILog("missing image data in response")
        throw OpenAIClientError.missingImageData
    }
    guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        writeOpenAILog("decode failed")
        throw OpenAIClientError.decodeFailed
    }
    writeOpenAILog("decode ok (w=\(image.width) h=\(image.height))")
    return image
}

private func writeOpenAILog(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] \(message)\n"
    guard let data = line.data(using: .utf8) else { return }
    let url = openAILogFileURL()
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

private func openAILogFileURL() -> URL {
    let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    let bundleId = Bundle.main.bundleIdentifier ?? "AiShot"
    let directory = cacheDirectory?.appendingPathComponent(bundleId, isDirectory: true)
    if let directory {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(openAILogFilename)
    }
    return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent(openAILogFilename)
}

private func makeOpenAISessionConfiguration() -> URLSessionConfiguration {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = openAIRequestTimeout
    configuration.timeoutIntervalForResource = openAIRequestTimeout * 2
    return configuration
}

private struct OpenAIImagesResponse: Decodable {
    let data: [OpenAIImageData]
}

private struct OpenAIImageData: Decodable {
    let b64_json: String?
}
