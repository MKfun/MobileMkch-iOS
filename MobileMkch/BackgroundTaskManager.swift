import Foundation
import BackgroundTasks
import UIKit

class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    private var backgroundTaskIdentifier: String {
        if let savedIdentifier = UserDefaults.standard.string(forKey: "BackgroundTaskIdentifier") {
            return savedIdentifier
        }
        return "com.mkch.MobileMkch.backgroundrefresh"
    }
    private let notificationManager = NotificationManager.shared
    
    private init() {}
    
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            self.handleBackgroundTask(task as! BGAppRefreshTask)
        }
    }
    
    func scheduleBackgroundTask() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        let settings = Settings()
        let interval = TimeInterval(settings.notificationInterval)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Не удалось запланировать фоновую задачу: \(error)")
        }
    }
    
    private func handleBackgroundTask(_ task: BGAppRefreshTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        let settings = Settings()
        guard settings.notificationsEnabled else {
            task.setTaskCompleted(success: true)
            return
        }
        
        let group = DispatchGroup()
        var hasNewThreads = false
        
        for boardCode in notificationManager.subscribedBoards {
            group.enter()
            
            let lastKnownId = UserDefaults.standard.integer(forKey: "lastThreadId_\(boardCode)")
            
            APIClient().checkNewThreads(forBoard: boardCode, lastKnownThreadId: lastKnownId) { result in
                switch result {
                case .success(let newThreads):
                    if !newThreads.isEmpty {
                        hasNewThreads = true
                        for thread in newThreads {
                            self.notificationManager.scheduleNotification(for: thread, boardCode: boardCode)
                        }
                        UserDefaults.standard.set(newThreads.first?.id ?? lastKnownId, forKey: "lastThreadId_\(boardCode)")
                    }
                case .failure:
                    break
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            task.setTaskCompleted(success: true)
            if hasNewThreads {
                self.scheduleBackgroundTask()
            }
        }
    }
} 