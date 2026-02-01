import Foundation

func currentAppVersion() -> String {
    (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.0.0"
}

func normalizeVersion(_ version: String) -> String {
    let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
    let lower = trimmed.lowercased()
    let clean = lower.hasPrefix("v") ? String(lower.dropFirst()) : lower
    return clean
}

func compareVersions(_ a: String, _ b: String) -> ComparisonResult {
    let aParts = versionParts(a)
    let bParts = versionParts(b)
    let count = max(aParts.count, bParts.count)
    for index in 0..<count {
        let aValue = index < aParts.count ? aParts[index] : 0
        let bValue = index < bParts.count ? bParts[index] : 0
        if aValue < bValue { return .orderedAscending }
        if aValue > bValue { return .orderedDescending }
    }
    return .orderedSame
}

private func versionParts(_ version: String) -> [Int] {
    return version.split(separator: ".").map { part in
        let digits = part.prefix { $0.isNumber }
        return Int(digits) ?? 0
    }
}
