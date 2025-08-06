import SwiftUI
import Combine
import Darwin

struct SettingsView: View {
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var apiClient: APIClient
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAbout = false
    @State private var showingInfo = false
    @State private var testKeyResult: String?
    @State private var testPasscodeResult: String?
    @State private var isTestingKey = false
    @State private var isTestingPasscode = false
    @State private var debugTapCount = 0
    @State private var showingDebugMenu = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Внешний вид") {
                    Picker("Тема", selection: $settings.theme) {
                        Text("Темная").tag("dark")
                        Text("Светлая").tag("light")
                    }
                    .onReceive(Just(settings.theme)) { _ in
                        settings.saveSettings()
                    }
                    
                    Toggle("Авторефреш", isOn: $settings.autoRefresh)
                        .onReceive(Just(settings.autoRefresh)) { _ in
                            settings.saveSettings()
                        }
                    
                    Toggle("Показывать файлы", isOn: $settings.showFiles)
                        .onReceive(Just(settings.showFiles)) { _ in
                            settings.saveSettings()
                        }
                    
                    Toggle("Компактный режим", isOn: $settings.compactMode)
                        .onReceive(Just(settings.compactMode)) { _ in
                            settings.saveSettings()
                        }
                    
                    Picker("Размер страницы", selection: $settings.pageSize) {
                        Text("5").tag(5)
                        Text("10").tag(10)
                        Text("15").tag(15)
                        Text("20").tag(20)
                    }
                    .onReceive(Just(settings.pageSize)) { _ in
                        settings.saveSettings()
                    }
                }
                
                Section("Последняя доска") {
                    Text(settings.lastBoard.isEmpty ? "Не выбрана" : settings.lastBoard)
                        .foregroundColor(.secondary)
                }
                
                Section("Аутентификация") {
                    SecureField("Passcode для постинга", text: $settings.passcode)
                        .onReceive(Just(settings.passcode)) { _ in
                            settings.saveSettings()
                        }
                    
                    SecureField("Ключ аутентификации", text: $settings.key)
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
                
                Section("Управление кэшем") {
                    Button("Очистить кэш досок") {
                        Cache.shared.delete("boards")
                    }
                    
                    Button("Очистить кэш тредов") {
                        apiClient.getBoards { result in
                            if case .success(let boards) = result {
                                for board in boards {
                                    Cache.shared.delete("threads_\(board.code)")
                                }
                            }
                        }
                    }
                    
                    Button("Очистить весь кэш") {
                        Cache.shared.clear()
                    }
                }
                
                Section("Сброс") {
                    Button("Сбросить настройки") {
                        settings.resetSettings()
                    }
                    .foregroundColor(.red)
                }
                
                Section {
                    Button("Об аппке") {
                        showingAbout = true
                    }
                    
                    Button("Я думаю тебя направили сюда") {
                        showingInfo = true
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .sheet(isPresented: $showingDebugMenu) {
                DebugMenuView()
            }
            .alert("Информация о НЕОЖИДАНЫХ проблемах", isPresented: $showingInfo) {
                Button("Закрыть") { }
            } message: {
                Text("Если тебя направили сюда, то значит ты попал на НЕИЗВЕДАННЫЕ ТЕРРИТОРИИ\n\nДА ДА, не ослышались, это не ошибка, это особенность\n\nУвы, разработчик имиджборда вставил палки в колеса\n\nИ без доната ему, например, постинг работать не будет\n\nУвы, постинг не работает без доната, а разработчик боится что на его сайте будут спам\n\nВкратце - на сайте работает капча, а наличие пасскода ее для вас отключает\n\nувы, конфет много, но на всех не хватит")
            }
        }
    }
    
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
                    Text("Версия: 1.0.0-ios-alpha (Always in alpha lol)")
                    Text("Автор: w^x (лейн, платон, а похуй как угодно)")
                    Text("Разработано с ❤️ на Свифт")
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

#Preview {
    SettingsView()
        .environmentObject(Settings())
        .environmentObject(APIClient())
} 