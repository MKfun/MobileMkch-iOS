import Foundation
import UserNotifications
import UIKit

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isNotificationsEnabled = false
    @Published var subscribedBoards: Set<String> = []
    
    private init() {
        checkNotificationStatus()
        loadSubscribedBoards()
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.isNotificationsEnabled = granted
                if granted {
                    self.registerForRemoteNotifications()
                }
                completion(granted)
            }
        }
    }
    
    private func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isNotificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func subscribeToBoard(_ boardCode: String) {
        subscribedBoards.insert(boardCode)
        saveSubscribedBoards()
        
        BackgroundTaskManager.shared.scheduleBackgroundTask()
    }
    
    private func syncThreadsForBoard(_ boardCode: String) {
        let url = URL(string: "https://mkch.pooziqo.xyz/api/board/\(boardCode)")!
        var request = URLRequest(url: url)
        request.setValue("MobileMkch/2.1.1-ios-alpha", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data,
               let threads = try? JSONDecoder().decode([Thread].self, from: data) {
                let savedThreadsKey = "savedThreads_\(boardCode)"
                if let encodedData = try? JSONEncoder().encode(threads) {
                    UserDefaults.standard.set(encodedData, forKey: savedThreadsKey)
                    print("Синхронизировано \(threads.count) тредов для /\(boardCode)/")
                }
            }
        }.resume()
    }
    
    func unsubscribeFromBoard(_ boardCode: String) {
        subscribedBoards.remove(boardCode)
        saveSubscribedBoards()
        
        let savedThreadsKey = "savedThreads_\(boardCode)"
        UserDefaults.standard.removeObject(forKey: savedThreadsKey)
    }
    
    func scheduleNotification(for thread: Thread, boardCode: String) {
        guard isNotificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Новый тред"
        content.body = "\(thread.title) в /\(boardCode)/"
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "thread_\(thread.id)_\(boardCode)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Ошибка планирования уведомления: \(error)")
            }
        }
    }
    
    func scheduleTestNotification() {
        guard isNotificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Тестовое уведомление"
        content.body = "Новый тред: Тестовый тред в /test/"
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "test_notification", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Ошибка планирования тестового уведомления: \(error)")
            }
        }
    }
    
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    func clearBadge() {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }
    
    func clearAllSavedThreads() {
        for boardCode in subscribedBoards {
            let savedThreadsKey = "savedThreads_\(boardCode)"
            UserDefaults.standard.removeObject(forKey: savedThreadsKey)
        }
        print("Очищены все сохраненные треды")
    }
    
    private func loadSubscribedBoards() {
        if let data = UserDefaults.standard.data(forKey: "subscribedBoards"),
           let boards = try? JSONDecoder().decode(Set<String>.self, from: data) {
            subscribedBoards = boards
        }
    }
    
    private func saveSubscribedBoards() {
        if let data = try? JSONEncoder().encode(subscribedBoards) {
            UserDefaults.standard.set(data, forKey: "subscribedBoards")
        }
    }
} 