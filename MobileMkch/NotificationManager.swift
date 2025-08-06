import Foundation
import UserNotifications
import UIKit

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
                completion(granted)
            }
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
    
    func unsubscribeFromBoard(_ boardCode: String) {
        subscribedBoards.remove(boardCode)
        saveSubscribedBoards()
    }
    
    func scheduleNotification(for thread: Thread, boardCode: String) {
        let content = UNMutableNotificationContent()
        content.title = "Новый тред"
        content.body = "\(thread.title) в /\(boardCode)/"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: "thread_\(thread.id)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func scheduleTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Тестовое уведомление"
        content.body = "Новый тред: Тестовый тред в /test/"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: "test_notification", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
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