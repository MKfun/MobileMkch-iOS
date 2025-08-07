import Foundation
import BackgroundTasks
import UIKit

class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    private var backgroundTaskIdentifier: String {
        // Используем идентификатор из Info.plist (BGTaskSchedulerPermittedIdentifiers)
        if let identifiers = Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String],
           let first = identifiers.first {
            return first
        }
        // Фоллбек на значение по умолчанию
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
        let interval = TimeInterval(settings.notificationInterval * 60)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Фоновая задача запланирована на \(interval) секунд")
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
            
            APIClient().checkNewThreads(forBoard: boardCode, lastKnownThreadId: 0) { result in
                switch result {
                case .success(let newThreads):
                    if !newThreads.isEmpty {
                        hasNewThreads = true
                        print("Найдено \(newThreads.count) новых тредов в /\(boardCode)/")
                        for thread in newThreads {
                            self.notificationManager.scheduleNotification(for: thread, boardCode: boardCode)
                        }
                    }
                case .failure(let error):
                    print("Ошибка проверки новых тредов для /\(boardCode)/: \(error)")
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