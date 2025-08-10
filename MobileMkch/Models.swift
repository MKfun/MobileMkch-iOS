import Foundation

private enum DateFormatterCache {
    static let iso8601 = ISO8601DateFormatter()
}

struct Board: Codable, Identifiable {
    let code: String
    let description: String
    var banner: String?
    
    var id: String { code }

    var bannerURL: String? {
        guard let banner = banner, !banner.isEmpty else { return nil }
        if banner.hasPrefix("http://") || banner.hasPrefix("https://") {
            return banner
        }
        return "https://mkch.pooziqo.xyz" + banner
    }

    private enum CodingKeys: String, CodingKey {
        case code
        case description
        case banner
    }
}

struct Thread: Codable, Identifiable {
    let id: Int
    let title: String
    let text: String
    let creation: String
    let board: String
    let rating: Int?
    let pinned: Bool?
    let files: [String]
    
    var creationDate: Date {
        return DateFormatterCache.iso8601.date(from: creation) ?? Date()
    }
    
    var ratingValue: Int {
        return rating ?? 0
    }
    
    var isPinned: Bool {
        return pinned ?? false
    }
}

struct ThreadDetail: Codable, Identifiable {
    let id: Int
    let creation: String
    let title: String
    let text: String
    let board: String
    let files: [String]
    
    var creationDate: Date {
        return DateFormatterCache.iso8601.date(from: creation) ?? Date()
    }
}

struct Comment: Codable, Identifiable {
    let id: Int
    let text: String
    let creation: String
    let files: [String]
    
    var creationDate: Date {
        return DateFormatterCache.iso8601.date(from: creation) ?? Date()
    }
    
    var formattedText: String {
        return text.replacingOccurrences(of: "#", with: ">>")
    }
}

struct FileInfo {
    let url: String
    let filename: String
    let isImage: Bool
    let isVideo: Bool
    let isGIF: Bool
    
    init(filePath: String) {
        self.url = "https://mkch.pooziqo.xyz" + filePath
        self.filename = String(filePath.split(separator: "/").last ?? "")
        
        let ext = filePath.lowercased()
        self.isGIF = ext.hasSuffix(".gif")
        self.isImage = ext.hasSuffix(".jpg") || ext.hasSuffix(".jpeg") || 
                      ext.hasSuffix(".png") || self.isGIF || 
                      ext.hasSuffix(".webp")
        self.isVideo = ext.hasSuffix(".mp4") || ext.hasSuffix(".webm")
    }
}

struct APIError: Error {
    let message: String
    let code: Int
    
    var localizedDescription: String {
        return message
    }
}

struct FavoriteThread: Codable, Identifiable {
    let id: Int
    let title: String
    let board: String
    let boardDescription: String
    let addedDate: Date
    
    init(thread: Thread, board: Board) {
        self.id = thread.id
        self.title = thread.title
        self.board = board.code
        self.boardDescription = board.description
        self.addedDate = Date()
    }
} 
