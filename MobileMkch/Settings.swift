import Foundation

class Settings: ObservableObject {
    @Published var theme: String = "dark"
    @Published var lastBoard: String = ""
    @Published var autoRefresh: Bool = true
    @Published var showFiles: Bool = true
    @Published var compactMode: Bool = false
    @Published var pageSize: Int = 10
    @Published var enablePagination: Bool = false
    @Published var enableUnstableFeatures: Bool = false
    @Published var passcode: String = ""
    @Published var key: String = ""
    @Published var notificationsEnabled: Bool = false
    @Published var notificationInterval: Int = 300
    @Published var favoriteThreads: [FavoriteThread] = []
    
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
            self.enablePagination = settings.enablePagination
            self.enableUnstableFeatures = settings.enableUnstableFeatures
            self.passcode = settings.passcode
            self.key = settings.key
            self.notificationsEnabled = settings.notificationsEnabled
            self.notificationInterval = settings.notificationInterval
            self.favoriteThreads = settings.favoriteThreads
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
            enablePagination: enablePagination,
            enableUnstableFeatures: enableUnstableFeatures,
            passcode: passcode,
            key: key,
            notificationsEnabled: notificationsEnabled,
            notificationInterval: notificationInterval,
            favoriteThreads: favoriteThreads
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
        enablePagination = false
        enableUnstableFeatures = false
        passcode = ""
        key = ""
        notificationsEnabled = false
        notificationInterval = 300
        favoriteThreads = []
        saveSettings()
    }
    
    func clearImageCache() {
        ImageCache.shared.clearCache()
    }
    
    func addToFavorites(_ thread: Thread, board: Board) {
        let favorite = FavoriteThread(thread: thread, board: board)
        if !favoriteThreads.contains(where: { $0.id == thread.id && $0.board == board.code }) {
            favoriteThreads.append(favorite)
            saveSettings()
        }
    }
    
    func removeFromFavorites(_ threadId: Int, boardCode: String) {
        favoriteThreads.removeAll { $0.id == threadId && $0.board == boardCode }
        saveSettings()
    }
    
    func isFavorite(_ threadId: Int, boardCode: String) -> Bool {
        return favoriteThreads.contains { $0.id == threadId && $0.board == boardCode }
    }
}

struct SettingsData: Codable {
    let theme: String
    let lastBoard: String
    let autoRefresh: Bool
    let showFiles: Bool
    let compactMode: Bool
    let pageSize: Int
    let enablePagination: Bool
    let enableUnstableFeatures: Bool
    let passcode: String
    let key: String
    let notificationsEnabled: Bool
    let notificationInterval: Int
    let favoriteThreads: [FavoriteThread]
} 