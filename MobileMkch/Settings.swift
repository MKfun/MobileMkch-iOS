import Foundation
import WidgetKit

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
    @Published var offlineMode: Bool = false
    @Published var liveActivityEnabled: Bool = false
    @Published var liveActivityShowTitle: Bool = true
    @Published var liveActivityShowLastComment: Bool = true
    @Published var liveActivityShowCommentCount: Bool = true
    @Published var liveActivityTickerEnabled: Bool = false
    @Published var liveActivityTickerRandomBoard: Bool = true
    @Published var liveActivityTickerBoardCode: String = "b"
    @Published var liveActivityTickerInterval: Int = 15
    @Published var hiddenBannerBoards: [String] = []
    @Published var shownBannerBoards: [String] = []
    
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "MobileMkchSettings"
    
    init() {
        loadSettings()
        mirrorStateToAppGroup()
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
            self.offlineMode = settings.offlineMode ?? false
            self.liveActivityEnabled = settings.liveActivityEnabled ?? false
            self.liveActivityShowTitle = settings.liveActivityShowTitle ?? true
            self.liveActivityShowLastComment = settings.liveActivityShowLastComment ?? true
            self.liveActivityShowCommentCount = settings.liveActivityShowCommentCount ?? true
            self.liveActivityTickerEnabled = settings.liveActivityTickerEnabled ?? false
            self.liveActivityTickerRandomBoard = settings.liveActivityTickerRandomBoard ?? true
            self.liveActivityTickerBoardCode = settings.liveActivityTickerBoardCode ?? "b"
            self.liveActivityTickerInterval = settings.liveActivityTickerInterval ?? 15
            self.hiddenBannerBoards = settings.hiddenBannerBoards ?? []
            self.shownBannerBoards = settings.shownBannerBoards ?? []
        }
        mirrorStateToAppGroup()
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
            ,
            offlineMode: offlineMode
            ,
            liveActivityEnabled: liveActivityEnabled,
            liveActivityShowTitle: liveActivityShowTitle,
            liveActivityShowLastComment: liveActivityShowLastComment,
            liveActivityShowCommentCount: liveActivityShowCommentCount,
            liveActivityTickerEnabled: liveActivityTickerEnabled,
            liveActivityTickerRandomBoard: liveActivityTickerRandomBoard,
            liveActivityTickerBoardCode: liveActivityTickerBoardCode,
            liveActivityTickerInterval: liveActivityTickerInterval,
            hiddenBannerBoards: hiddenBannerBoards,
            shownBannerBoards: shownBannerBoards
        )
        
        if let data = try? JSONEncoder().encode(settingsData) {
            userDefaults.set(data, forKey: settingsKey)
        }
        mirrorStateToAppGroup()
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func isBannerHidden(_ boardCode: String) -> Bool {
        if shownBannerBoards.isEmpty && hiddenBannerBoards.isEmpty {
            return boardCode != "b"
        }
        if shownBannerBoards.contains(boardCode) { return false }
        return hiddenBannerBoards.contains(boardCode)
    }
    
    func setBannerVisible(_ boardCode: String, visible: Bool) {
        if visible {
            if let idx = hiddenBannerBoards.firstIndex(of: boardCode) { hiddenBannerBoards.remove(at: idx) }
            if !shownBannerBoards.contains(boardCode) { shownBannerBoards.append(boardCode) }
        } else {
            if let idx = shownBannerBoards.firstIndex(of: boardCode) { shownBannerBoards.remove(at: idx) }
            if !hiddenBannerBoards.contains(boardCode) { hiddenBannerBoards.append(boardCode) }
        }
        saveSettings()
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
        offlineMode = false
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
    
    private func mirrorStateToAppGroup() {
        guard let shared = AppGroup.defaults else { return }
        let mapped = favoriteThreads.map { FavoriteThreadWidget(id: $0.id, title: $0.title, board: $0.board, boardDescription: $0.boardDescription, addedDate: $0.addedDate) }
        if let encodedFavorites = try? JSONEncoder().encode(mapped) {
            shared.set(encodedFavorites, forKey: "favoriteThreads")
        }
        shared.set(offlineMode, forKey: "offlineMode")
        shared.set(lastBoard, forKey: "lastBoard")
        WidgetCenter.shared.reloadTimelines(ofKind: "FavoritesWidget")
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
    let offlineMode: Bool?
    let liveActivityEnabled: Bool?
    let liveActivityShowTitle: Bool?
    let liveActivityShowLastComment: Bool?
    let liveActivityShowCommentCount: Bool?
    let liveActivityTickerEnabled: Bool?
    let liveActivityTickerRandomBoard: Bool?
    let liveActivityTickerBoardCode: String?
    let liveActivityTickerInterval: Int?
    let hiddenBannerBoards: [String]?
    let shownBannerBoards: [String]?
} 