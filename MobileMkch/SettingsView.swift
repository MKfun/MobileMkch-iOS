import SwiftUI
import Combine
import Darwin
import ActivityKit

struct SettingsView: View {
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var apiClient: APIClient
    @EnvironmentObject var networkMonitor: NetworkMonitor
    
    @State private var isTickerRunning = false
    @State private var showingAbout = false
    @State private var showingInfo = false
    @State private var testKeyResult: String?
    @State private var testPasscodeResult: String?
    @State private var isTestingKey = false
    @State private var isTestingPasscode = false
    @State private var debugTapCount = 0
    @State private var showingDebugMenu = false
    @State private var showingUnstableWarning = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Внешний вид") {
                    HStack {
                        Image(systemName: "moon.fill")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        Text("Тема")
                        Spacer()
                        Picker("", selection: $settings.theme) {
                            Text("Темная").tag("dark")
                            Text("Светлая").tag("light")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 120)
                    }
                    .onReceive(Just(settings.theme)) { _ in
                        settings.saveSettings()
                    }
                    
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        Toggle("Авторефреш", isOn: $settings.autoRefresh)
                    }
                    .onReceive(Just(settings.autoRefresh)) { _ in
                        settings.saveSettings()
                    }
                    
                    HStack {
                        Image(systemName: "paperclip")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Toggle("Показывать файлы", isOn: $settings.showFiles)
                    }
                    .onReceive(Just(settings.showFiles)) { _ in
                        settings.saveSettings()
                    }
                    
                    HStack {
                        Image(systemName: "rectangle.compress.vertical")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        Toggle("Компактный режим", isOn: $settings.compactMode)
                    }
                    .onReceive(Just(settings.compactMode)) { _ in
                        settings.saveSettings()
                    }
                    
                    HStack {
                        Image(systemName: "list.bullet")
                            .foregroundColor(.indigo)
                            .frame(width: 24)
                        Text("Размер страницы")
                        Spacer()
                        Picker("", selection: $settings.pageSize) {
                            Text("5").tag(5)
                            Text("10").tag(10)
                            Text("15").tag(15)
                            Text("20").tag(20)
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    .onReceive(Just(settings.pageSize)) { _ in
                        settings.saveSettings()
                    }
                    
                    HStack {
                        Image(systemName: "rectangle.split.2x1")
                            .foregroundColor(.teal)
                            .frame(width: 24)
                        Toggle("Разстраничивание", isOn: $settings.enablePagination)
                    }
                    .onReceive(Just(settings.enablePagination)) { _ in
                        settings.saveSettings()
                    }
                    
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        Toggle("Нестабильные функции", isOn: $settings.enableUnstableFeatures)
                    }
                    .onReceive(Just(settings.enableUnstableFeatures)) { newValue in
                        if newValue && !UserDefaults.standard.bool(forKey: "hasShownUnstableWarning") {
                            showingUnstableWarning = true
                            UserDefaults.standard.set(true, forKey: "hasShownUnstableWarning")
                        }
                        settings.saveSettings()
                    }
                }
                
                Section("Оффлайн режим") {
                    HStack {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        Toggle("Принудительно оффлайн", isOn: $settings.offlineMode)
                    }
                    .onChange(of: settings.offlineMode) { newValue in
                        if networkMonitor.forceOffline != newValue {
                            networkMonitor.forceOffline = newValue
                            settings.saveSettings()
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(networkMonitor.offlineEffective ? "Сейчас оффлайн: показываем кэш" : "Онлайн: будут загружаться свежие данные")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Аутентификация") {
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        SecureField("Passcode для постинга", text: $settings.passcode)
                    }
                    .onReceive(Just(settings.passcode)) { _ in
                        settings.saveSettings()
                    }
                    
                    HStack {
                        Image(systemName: "key")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        SecureField("Ключ аутентификации", text: $settings.key)
                    }
                    .onReceive(Just(settings.key)) { _ in
                        settings.saveSettings()
                    }
                    
                    HStack {
                        Button("Тест ключа") {
                            testKey()
                        }
                        .disabled(settings.key.isEmpty || isTestingKey)
                        
                        if isTestingKey {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        
                        if let result = testKeyResult {
                            Text(result)
                                .font(.caption)
                                .foregroundColor(result.contains("успешно") ? .green : .red)
                        }
                    }
                    
                    HStack {
                        Button("Тест passcode") {
                            testPasscode()
                        }
                        .disabled(settings.passcode.isEmpty || isTestingPasscode)
                        
                        if isTestingPasscode {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        
                        if let result = testPasscodeResult {
                            Text(result)
                                .font(.caption)
                                .foregroundColor(result.contains("успешно") ? .green : .red)
                        }
                    }
                }
                
                Section("Уведомления") {
                    NavigationLink("Настройки уведомлений") {
                        NotificationSettingsView()
                            .environmentObject(apiClient)
                    }
                    .overlay(
                        HStack {
                            Spacer()
                            Image(systemName: "sparkles")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        .padding(.trailing, 8)
                    )
                    if #available(iOS 16.1, *) {
                        Toggle("Live Activity", isOn: $settings.liveActivityEnabled)
                            .onReceive(Just(settings.liveActivityEnabled)) { _ in
                                settings.saveSettings()
                            }
                        if settings.liveActivityEnabled {
                            Toggle("Показывать заголовок", isOn: $settings.liveActivityShowTitle)
                                .onReceive(Just(settings.liveActivityShowTitle)) { _ in settings.saveSettings() }
                            Toggle("Показывать последний коммент", isOn: $settings.liveActivityShowLastComment)
                                .onReceive(Just(settings.liveActivityShowLastComment)) { _ in settings.saveSettings() }
                            Toggle("Показывать счётчик", isOn: $settings.liveActivityShowCommentCount)
                                .onReceive(Just(settings.liveActivityShowCommentCount)) { _ in settings.saveSettings() }
                            Toggle("Тикер случайных тредов", isOn: $settings.liveActivityTickerEnabled)
                                .onReceive(Just(settings.liveActivityTickerEnabled)) { _ in settings.saveSettings() }
                            if settings.liveActivityTickerEnabled {
                                Toggle("Случайная борда", isOn: $settings.liveActivityTickerRandomBoard)
                                    .onReceive(Just(settings.liveActivityTickerRandomBoard)) { _ in settings.saveSettings() }
                                if !settings.liveActivityTickerRandomBoard {
                                    HStack {
                                        Text("Код борды")
                                        TextField("b", text: $settings.liveActivityTickerBoardCode)
                                            .textInputAutocapitalization(.never)
                                            .disableAutocorrection(true)
                                    }
                                    .onReceive(Just(settings.liveActivityTickerBoardCode)) { _ in settings.saveSettings() }
                                }
                                HStack {
                                    Text("Интервал, сек")
                                    Spacer()
                                    Stepper(value: $settings.liveActivityTickerInterval, in: 5...120, step: 5) {
                                        Text("\(settings.liveActivityTickerInterval)")
                                    }
                                }
                                .onReceive(Just(settings.liveActivityTickerInterval)) { _ in settings.saveSettings() }
                                HStack(spacing: 12) {
                                    Button("Старт тикера") {
                                        LiveActivityManager.shared.startTicker(settings: settings, apiClient: apiClient)
                                        isTickerRunning = true
                                    }
                                        .buttonStyle(.bordered)
                                        .tint(.green)
                                    Button("Стоп тикера") {
                                        LiveActivityManager.shared.stopTicker()
                                        isTickerRunning = false
                                    }
                                        .buttonStyle(.bordered)
                                        .tint(.red)
                                    Spacer()
                                    Text(isTickerRunning ? "Работает" : "Остановлен")
                                        .font(.caption)
                                        .foregroundColor(isTickerRunning ? .green : .secondary)
                                }
                                .onAppear { isTickerRunning = LiveActivityManager.shared.isTickerRunning }
                            }
                            Text("В фоне частые обновления ограничены системой")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Управление кэшем") {
                    Button(action: {
                        Cache.shared.delete("boards")
                    }) {
                        HStack {
                            Image(systemName: "list.bullet")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("Очистить кэш досок")
                            Spacer()
                        }
                    }
                    
                    Button(action: {
                        apiClient.getBoards { result in
                            if case .success(let boards) = result {
                                for board in boards {
                                    Cache.shared.delete("threads_\(board.code)")
                                }
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            Text("Очистить кэш тредов")
                            Spacer()
                        }
                    }
                    
                    Button(action: {
                        settings.clearImageCache()
                    }) {
                        HStack {
                            Image(systemName: "photo")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            Text("Очистить кэш изображений")
                            Spacer()
                        }
                    }
                    
                    Button(action: {
                        Cache.shared.clear()
                        settings.clearImageCache()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .frame(width: 24)
                            Text("Очистить весь кэш")
                            Spacer()
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        settings.resetSettings()
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.red)
                                .frame(width: 24)
                            Text("Сбросить настройки")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        showingAbout = true
                    }) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("Об аппке")
                            Spacer()
                        }
                    }
                    
                    Button(action: {
                        showingInfo = true
                    }) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            Text("Я думаю тебя направили сюда")
                            Spacer()
                        }
                    }
                }
                
                Section("Информация об устройстве") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Устройство: \(getDeviceModel())")
                        Text("Система: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
                        Text("Тип: \(UIDevice.current.name.isEmpty ? "Не удалось определить, увы" : UIDevice.current.name)")
                        Text("Идентификатор: \(UIDevice.current.identifierForVendor?.uuidString ?? "Неизвестно")")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .onTapGesture {
                        debugTapCount += 1
                        if debugTapCount >= 5 {
                            showingDebugMenu = true
                            debugTapCount = 0
                        }
                    }
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .sheet(isPresented: $showingDebugMenu) {
                DebugMenuView()
                    .environmentObject(NotificationManager.shared)
            }
            .sheet(isPresented: $showingUnstableWarning) {
                UnstableFeaturesWarningView(isPresented: $showingUnstableWarning)
            }
            .alert("Информация о НЕОЖИДАНЫХ проблемах", isPresented: $showingInfo) {
                Button("Закрыть") { }
            } message: {
                Text("Если тебя направили сюда, то значит ты попал на НЕИЗВЕДАННЫЕ ТЕРРИТОРИИ\n\nДА ДА, не ослышались, это не ошибка, это особенность\n\nУвы, разработчик имиджборда вставил палки в колеса\n\nИ без доната ему, например, постинг работать не будет\n\nУвы, постинг не работает без доната, а разработчик боится что на его сайте будут спам\n\nВкратце - на сайте работает капча, а наличие пасскода ее для вас отключает\n\nувы, конфет много, но на всех не хватит")
            }
        }
    }
}

extension SettingsView {
    private func testKey() {
        guard !settings.key.isEmpty else { return }
        
        isTestingKey = true
        testKeyResult = nil
        
        apiClient.authenticate(authKey: settings.key) { error in
            DispatchQueue.main.async {
                self.isTestingKey = false
                
                if let error = error {
                    self.testKeyResult = "Ошибка: \(error.localizedDescription)"
                } else {
                    self.testKeyResult = "Аутентификация успешна"
                }
            }
        }
    }
    
    private func testPasscode() {
        guard !settings.passcode.isEmpty else { return }
        
        isTestingPasscode = true
        testPasscodeResult = nil
        
        apiClient.loginWithPasscode(passcode: settings.passcode) { error in
            DispatchQueue.main.async {
                self.isTestingPasscode = false
                
                if let error = error {
                    self.testPasscodeResult = "Ошибка: \(error.localizedDescription)"
                } else {
                    self.testPasscodeResult = "Вход успешен"
                }
            }
        }
    }
    
    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        return identifier
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("MobileMkch")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Мобильный клиент для мкача")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Версия: 2.1.0-ios-alpha (Always in alpha lol)")
                    Text("Автор: w^x (лейн, платон, а похуй как угодно)")
                    Text("Разработано с <3 на Свифт")
                }
                .font(.body)
                
                Spacer()
                
                Button("Закрыть") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("Об аппке")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct DebugMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var liveActivityStarted = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Debug Menu")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                VStack(spacing: 15) {
                    Button("Тест краша") {
                        CrashHandler.shared.triggerTestCrash()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundColor(.red)
                    
                    Button("Тест уведомления") {
                        notificationManager.scheduleTestNotification()
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundColor(.blue)
                    if #available(iOS 16.1, *) {
                        Button(liveActivityStarted ? "Остановить Live Activity" : "Тест Live Activity") {
                            if liveActivityStarted {
                                LiveActivityManager.shared.end(threadId: 999999)
                                liveActivityStarted = false
                            } else {
                                let detail = ThreadDetail(id: 999999, creation: "2023-01-01T00:00:00Z", title: "Тестовый тред", text: "", board: "b", files: [])
                                let comments = [Comment(id: 1, text: "Привет из Live Activity", creation: "2023-01-01T00:00:00Z", files: [])]
                                var s = Settings()
                                s.liveActivityEnabled = true
                                s.liveActivityShowTitle = true
                                s.liveActivityShowLastComment = true
                                s.liveActivityShowCommentCount = true
                                LiveActivityManager.shared.start(for: detail, comments: comments, settings: s)
                                liveActivityStarted = true
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                Spacer()
                
                Button("Закрыть") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct UnstableFeaturesWarningView: View {
    @Binding var isPresented: Bool
    @State private var timeRemaining = 10
    @State private var canConfirm = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                
                Text("ВНИМАНИЕ!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                
                VStack(spacing: 12) {
                    Text("Вы собираетесь включить нестабильные функции")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    Text("Эти функции находятся в разработке и могут:")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Работать нестабильно или не работать вовсе")
                        Text("Вызывать краши приложения")
                        Text("Потреблять больше ресурсов")
                        Text("Иметь неожиданное поведение")
                    }
                    .font(.body)
                    .foregroundColor(.secondary)
                    
                    Text("НИКАКИЕ ЖАЛОБЫ на нестабильный функционал НЕ ПРИНИМАЮТСЯ!")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.top)
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    if !canConfirm {
                        Text("Подтверждение будет доступно через: \(timeRemaining)")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                    
                    Button(action: {
                        isPresented = false
                    }) {
                        Text(canConfirm ? "Я уверен!" : "Отмена")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canConfirm ? Color.red : Color.gray)
                            .cornerRadius(10)
                    }
                    .disabled(!canConfirm)
                }
            }
            .padding()
            .navigationTitle("Предупреждение")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                startTimer()
            }
        }
    }
    
    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                canConfirm = true
                timer.invalidate()
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(Settings())
        .environmentObject(APIClient())
} 
