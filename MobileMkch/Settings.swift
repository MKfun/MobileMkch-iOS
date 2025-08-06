import Foundation

class Settings: ObservableObject {
    @Published var theme: String = "dark"
    @Published var lastBoard: String = ""
    @Published var autoRefresh: Bool = true
    @Published var showFiles: Bool = true
    @Published var compactMode: Bool = false
    @Published var pageSize: Int = 10
    @Published var passcode: String = ""
    @Published var key: String = ""
    
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "MobileMkchSettings"
    
    init() {
        loadSettings()
    }
    
    func loadSettings() {
        if let data = userDefaults.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(SettingsData.self, from: data) {
            self.theme = settings.theme
            self.lastBoard = settings.lastBoard
            self.autoRefresh = settings.autoRefresh
            self.showFiles = settings.showFiles
            self.compactMode = settings.compactMode
            self.pageSize = settings.pageSize
            self.passcode = settings.passcode
            self.key = settings.key
        }
    }
    
    func saveSettings() {
        let settingsData = SettingsData(
            theme: theme,
            lastBoard: lastBoard,
            autoRefresh: autoRefresh,
            showFiles: showFiles,
            compactMode: compactMode,
            pageSize: pageSize,
            passcode: passcode,
            key: key
        )
        
        if let data = try? JSONEncoder().encode(settingsData) {
            userDefaults.set(data, forKey: settingsKey)
        }
    }
    
    func resetSettings() {
        theme = "dark"
        lastBoard = ""
        autoRefresh = true
        showFiles = true
        compactMode = false
        pageSize = 10
        passcode = ""
        key = ""
        saveSettings()
    }
}

struct SettingsData: Codable {
    let theme: String
    let lastBoard: String
    let autoRefresh: Bool
    let showFiles: Bool
    let compactMode: Bool
    let pageSize: Int
    let passcode: String
    let key: String
} 