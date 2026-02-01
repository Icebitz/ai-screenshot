import Foundation
import UserNotifications
import Cocoa

final class UpdateManager: NSObject, UNUserNotificationCenterDelegate {
    private let owner: String
    private let repo: String
    private let interval: TimeInterval
    private var timer: Timer?
    private var lastNotifiedVersion: String?
    
    init(owner: String, repo: String, interval: TimeInterval = 3600) {
        self.owner = owner
        self.repo = repo
        self.interval = interval
    }
    
    func start() {
        stop()
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("UpdateManager: notification permission error \(error)")
            } else if !granted {
                print("UpdateManager: notification permission not granted")
            }
        }
        
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkForUpdates()
        }
        timer.tolerance = min(300, interval * 0.1)
        self.timer = timer
        checkForUpdates()
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkForUpdates() {
        Task {
            await fetchLatestRelease()
        }
    }
    
    private func fetchLatestRelease() async {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest") else {
            print("UpdateManager: invalid release URL")
            return
        }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("AiShotUpdateChecker", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                print("UpdateManager: release fetch status \(http.statusCode)")
                return
            }
            guard let release = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("UpdateManager: invalid release JSON")
                return
            }
            guard let tag = release["tag_name"] as? String else {
                print("UpdateManager: missing tag_name")
                return
            }
            let latestVersion = normalizeVersion(tag)
            let currentVersion = normalizeVersion(currentAppVersion())
            let releaseURL = release["html_url"] as? String
            
            if compareVersions(latestVersion, currentVersion) == .orderedDescending {
                notifyUpdate(latestVersion: latestVersion, currentVersion: currentVersion, releaseURL: releaseURL)
            }
        } catch {
            print("UpdateManager: release fetch error \(error)")
        }
    }
    
    private func notifyUpdate(latestVersion: String, currentVersion: String, releaseURL: String?) {
        guard lastNotifiedVersion != latestVersion else { return }
        lastNotifiedVersion = latestVersion
        
        let content = UNMutableNotificationContent()
        content.title = "Update available"
        content.body = "AiShot \(latestVersion) is available (current \(currentVersion))."
        if let releaseURL {
            content.userInfo = ["url": releaseURL]
        }
        let request = UNNotificationRequest(
            identifier: "AiShotUpdate-\(latestVersion)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("UpdateManager: notification error \(error)")
            }
        }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        if let urlString = response.notification.request.content.userInfo["url"] as? String,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
