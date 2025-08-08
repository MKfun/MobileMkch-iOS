import Foundation

enum AppGroup {
    static let identifier = "group.mobilemkch"
    static var defaults: UserDefaults? { UserDefaults(suiteName: identifier) }
}

struct FavoriteThreadWidget: Identifiable, Codable {
    let id: Int
    let title: String
    let board: String
    let boardDescription: String
    let addedDate: Date
}


