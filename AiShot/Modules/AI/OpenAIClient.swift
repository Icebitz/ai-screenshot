import Foundation

enum OpenAIClientError: Error {
    case invalidResponse
    case requestFailed(statusCode: Int)
    case missingImageData
    case decodeFailed
}
