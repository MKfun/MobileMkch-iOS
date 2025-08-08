import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var apiClient: APIClient
    @State private var showingPermissionAlert = false
    @State private var boards: [Board] = []
    @State private var isLoadingBoards = false
    @State private var isCheckingThreads = false
    @State private var showingTestNotification = false
    
    var body: some View {
        VStack {
            if !settings.enableUnstableFeatures {
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("Функция заблокирована")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Для использования уведомлений необходимо включить нестабильные функции в настройках.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("BETA Функция")
                        .font(.headline)
                        .foregroundColor(.orange)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                
                Text("Уведомления находятся в бета-версии и могут работать нестабильно.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom)
                
                Form {
                    Section(header: Text("Уведомления")) {
                        Toggle("Включить уведомления", isOn: $settings.notificationsEnabled)
                            .onChange(of: settings.notificationsEnabled) { newValue in
                                if newValue {
                                    requestNotificationPermission()
                                }
                                settings.saveSettings()
                            }
                        
                        if settings.notificationsEnabled {
                            HStack {
                                Text("Интервал проверки")
                                Spacer()
                                Picker("", selection: $settings.notificationInterval) {
                                    Text("5 мин").tag(300)
                                    Text("15 мин").tag(900)
                                    Text("30 мин").tag(1800)
                                    Text("1 час").tag(3600)
                                }
                                .pickerStyle(MenuPickerStyle())
                            }
                            .onChange(of: settings.notificationInterval) { _ in
                                settings.saveSettings()
                                BackgroundTaskManager.shared.scheduleBackgroundTask()
                            }
                            
                            Button(action: {
                                showingTestNotification = true
                                notificationManager.scheduleTestNotification()
                            }) {
                                HStack {
                                    Image(systemName: "bell.badge")
                                    Text("Отправить тестовое уведомление")
                                }
                            }
                            .foregroundColor(.blue)
                            .disabled(!notificationManager.isNotificationsEnabled)
                            
                            Button(action: {
                                isCheckingThreads = true
                                checkNewThreadsNow()
                            }) {
                                HStack {
                                    if isCheckingThreads {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    Text("Проверить новые треды сейчас")
                                }
                            }
                            .foregroundColor(.blue)
                            .disabled(isCheckingThreads || notificationManager.subscribedBoards.isEmpty)
                            
                            Button(action: {
                                syncAllBoards()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Синхронизировать все доски")
                                }
                            }
                            .foregroundColor(.orange)
                            .disabled(notificationManager.subscribedBoards.isEmpty)
                            
                            Button(action: {
                                notificationManager.clearAllSavedThreads()
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Очистить все сохраненные треды")
                                }
                            }
                            .foregroundColor(.red)
                            .disabled(notificationManager.subscribedBoards.isEmpty)
                        }
                    }
                    
                    if settings.notificationsEnabled {
                        Section(header: Text("Подписки на доски")) {
                            if isLoadingBoards {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Загрузка досок...")
                                        .foregroundColor(.secondary)
                                }
                            } else if boards.isEmpty {
                                Text("Не удалось загрузить доски")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(boards) { board in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("/\(board.code)/")
                                                .font(.headline)
                                            Text(board.description.isEmpty ? "Без описания" : board.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        Toggle("", isOn: Binding(
                                            get: { notificationManager.subscribedBoards.contains(board.code) },
                                            set: { isSubscribed in
                                                if isSubscribed {
                                                    notificationManager.subscribeToBoard(board.code)
                                                } else {
                                                    notificationManager.unsubscribeFromBoard(board.code)
                                                }
                                            }
                                        ))
                                    }
                                }
                            }
                        }
                        
                        Section(header: Text("Статус")) {
                            HStack {
                                Text("Разрешения")
                                Spacer()
                                Text(notificationManager.isNotificationsEnabled ? "Включены" : "Отключены")
                                    .foregroundColor(notificationManager.isNotificationsEnabled ? .green : .red)
                            }
                            
                            HStack {
                                Text("Подписки")
                                Spacer()
                                Text("\(notificationManager.subscribedBoards.count) досок")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Уведомления")
        .onAppear {
            if boards.isEmpty {
                loadBoards()
            }
        }
        .alert("Разрешить уведомления", isPresented: $showingPermissionAlert) {
            Button("Настройки") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Отмена", role: .cancel) {
                settings.notificationsEnabled = false
            }
        } message: {
            Text("Для получения уведомлений о новых тредах необходимо разрешить уведомления в настройках")
        }
        .alert("Тестовое уведомление", isPresented: $showingTestNotification) {
            Button("OK") { }
        } message: {
            Text("Тестовое уведомление отправлено. Проверьте, получили ли вы его.")
        }
    }
}

extension NotificationSettingsView {
    private func requestNotificationPermission() {
        notificationManager.requestPermission { granted in
            if !granted {
                showingPermissionAlert = true
            }
        }
    }
    
    private func checkNewThreadsNow() {
        guard !notificationManager.subscribedBoards.isEmpty else { return }
        
        let group = DispatchGroup()
        var foundNewThreads = false
        
        for boardCode in notificationManager.subscribedBoards {
            group.enter()
            
            apiClient.checkNewThreads(forBoard: boardCode, lastKnownThreadId: 0) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let newThreads):
                        if !newThreads.isEmpty {
                            foundNewThreads = true
                            for thread in newThreads {
                                notificationManager.scheduleNotification(for: thread, boardCode: boardCode)
                            }
                        }
                    case .failure(let error):
                        print("Ошибка проверки тредов для /\(boardCode)/: \(error)")
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            isCheckingThreads = false
            if !foundNewThreads {
                print("Новых тредов не найдено")
            }
        }
    }
    
    private func syncAllBoards() {
        for boardCode in notificationManager.subscribedBoards {
            let savedThreadsKey = "savedThreads_\(boardCode)"
            UserDefaults.standard.removeObject(forKey: savedThreadsKey)
            
            let url = URL(string: "https://mkch.pooziqo.xyz/api/board/\(boardCode)")!
            var request = URLRequest(url: url)
            request.setValue("MobileMkch/2.1.1-ios-alpha", forHTTPHeaderField: "User-Agent")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let data = data,
                   let threads = try? JSONDecoder().decode([Thread].self, from: data) {
                    if let encodedData = try? JSONEncoder().encode(threads) {
                        UserDefaults.standard.set(encodedData, forKey: savedThreadsKey)
                        print("Синхронизировано \(threads.count) тредов для /\(boardCode)/")
                    }
                }
            }.resume()
        }
    }
    
    private func loadBoards() {
        isLoadingBoards = true
        
        apiClient.getBoards { result in
            DispatchQueue.main.async {
                isLoadingBoards = false
                
                switch result {
                case .success(let loadedBoards):
                    boards = loadedBoards
                case .failure:
                    boards = []
                }
            }
        }
    }
} 