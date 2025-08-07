import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var apiClient: APIClient
    @State private var showingPermissionAlert = false
    @State private var boards: [Board] = []
    @State private var isLoadingBoards = false
    
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
                
                Text("Уведомления находятся в бета-версии и могут работать нестабильно. Функция может работать нестабильно или не работать ВОВСЕ.")
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
                            }
                            
                            Button("Проверить новые треды сейчас") {
                                checkNewThreadsNow()
                            }
                            .foregroundColor(.blue)
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
        
        for boardCode in notificationManager.subscribedBoards {
            let lastKnownId = UserDefaults.standard.integer(forKey: "lastThreadId_\(boardCode)")
            
            apiClient.checkNewThreads(forBoard: boardCode, lastKnownThreadId: lastKnownId) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let newThreads):
                        if !newThreads.isEmpty {
                            for thread in newThreads {
                                notificationManager.scheduleNotification(for: thread, boardCode: boardCode)
                            }
                            UserDefaults.standard.set(newThreads.first?.id ?? lastKnownId, forKey: "lastThreadId_\(boardCode)")
                        }
                    case .failure:
                        break
                    }
                }
            }
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