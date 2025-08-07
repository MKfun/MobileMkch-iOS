import Foundation

struct Board: Codable, Identifiable {
    let code: String
    let description: String
    
    var id: String { code }
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
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: creation) ?? Date()
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
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: creation) ?? Date()
    }
}

struct Comment: Codable, Identifiable {
    let id: Int
    let text: String
    let creation: String
    let files: [String]
    
    var creationDate: Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: creation) ?? Date()
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
    
    init(filePath: String) {
        self.url = "https://mkch.pooziqo.xyz" + filePath
        self.filename = String(filePath.split(separator: "/").last ?? "")
        
        let ext = filePath.lowercased()
        self.isImage = ext.hasSuffix(".jpg") || ext.hasSuffix(".jpeg") || 
                      ext.hasSuffix(".png") || ext.hasSuffix(".gif") || 
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