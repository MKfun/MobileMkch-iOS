//
//  FavoritesWidget.swift
//  FavoritesWidget
//
//  Created by Platon on 08.08.2025.
//

import WidgetKit
import SwiftUI
import ActivityKit

private let appGroupId = "group.mobilemkch"

struct FavoriteThreadWidget: Identifiable, Codable {
    let id: Int
    let title: String
    let board: String
    let boardDescription: String
    let addedDate: Date
}

struct ThreadDTO: Codable, Identifiable {
    let id: Int
    let title: String
    let board: String
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let favorites: [FavoriteThreadWidget]
    let offline: Bool
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), favorites: [
            FavoriteThreadWidget(id: 1, title: "Загрузка...", board: "b", boardDescription: "", addedDate: Date())
        ], offline: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let favs = loadFavorites()
        if favs.isEmpty {
            Task {
                let networkFavs = await loadFromNetwork(board: "b")
                completion(SimpleEntry(date: Date(), favorites: networkFavs, offline: false))
            }
        } else {
            completion(SimpleEntry(date: Date(), favorites: favs, offline: loadOffline()))
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        Task {
            var favorites = loadFavorites()
            var offline = loadOffline()
            if favorites.isEmpty {
                favorites = await loadFromNetwork(board: "b")
                offline = false
            }
            let entry = SimpleEntry(date: Date(), favorites: favorites, offline: offline)
            let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
            let timeline = Timeline(entries: [entry], policy: .after(refresh))
            completion(timeline)
        }
    }
    
    private func loadFavorites() -> [FavoriteThreadWidget] {
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let data = defaults.data(forKey: "favoriteThreads"),
              let items = try? JSONDecoder().decode([FavoriteThreadWidget].self, from: data) else {
            return []
        }
        return items
    }
    
    private func loadOffline() -> Bool {
        let defaults = UserDefaults(suiteName: appGroupId)
        return defaults?.bool(forKey: "offlineMode") ?? false
    }
    
    private func sample() -> [FavoriteThreadWidget] {
        []
    }

    private func loadFromNetwork(board: String) async -> [FavoriteThreadWidget] {
        guard let url = URL(string: "https://mkch.pooziqo.xyz/api/board/\(board)") else { return [] }
        var req = URLRequest(url: url)
        req.setValue("MobileMkch/2.1.1-widget", forHTTPHeaderField: "User-Agent")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let threads = try JSONDecoder().decode([ThreadDTO].self, from: data)
            return Array(threads.prefix(3)).map { t in
                FavoriteThreadWidget(id: t.id, title: t.title, board: t.board, boardDescription: "", addedDate: Date())
            }
        } catch {
            return []
        }
    }
}

struct FavoritesWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            header
            content
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(padding)
        .background(
            Group {
                if #available(iOS 17.0, *) {
                    Color.clear
                        .containerBackground(for: .widget) {
                            Color.clear
                        }
                } else {
                    Color.clear
                }
            }
        )
    }
    
    private var spacing: CGFloat { family == .systemSmall ? 4 : 6 }
    private var padding: CGFloat { family == .systemSmall ? 8 : 12 }
    private var titleFont: Font { family == .systemSmall ? .caption2 : .caption }
    private var headerFont: Font { family == .systemSmall ? .footnote : .headline }
    private var maxItems: Int { family == .systemSmall ? 1 : 3 }
    
    @ViewBuilder private var header: some View {
        HStack(spacing: 6) {
            Text("Избранное")
                .font(headerFont)
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
            if entry.offline {
                Image(systemName: "wifi.slash").foregroundColor(.orange)
            }
        }
    }
    
    @ViewBuilder private var content: some View {
        if entry.favorites.isEmpty {
            Text("Пусто")
                .foregroundColor(.secondary)
                .font(titleFont)
        } else {
            ForEach(entry.favorites.prefix(maxItems)) { fav in
                if family == .systemSmall {
                    HStack(spacing: 6) {
                        BoardTag(code: fav.board)
                        Text(fav.title)
                            .font(titleFont)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        BoardTag(code: fav.board)
                        Text(fav.title)
                            .font(titleFont)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        }
    }
}

private struct BoardTag: View {
    let code: String
    var body: some View {
        Text("/\(code)/")
            .font(.caption2)
            .foregroundColor(.blue)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.blue.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

struct FavoritesWidget: Widget {
    let kind: String = "FavoritesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            FavoritesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Избранное MobileMkch")
        .description("Показывает избранные треды или топ по выбранной доске.")
    }
}

@available(iOS 16.1, *)
struct ThreadActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var latestCommentText: String
        var commentsCount: Int
        var showTitle: Bool
        var showLastComment: Bool
        var showCommentCount: Bool
        var currentTitle: String
        var currentBoard: String
    }

    var threadId: Int
    var title: String
    var board: String
}

@available(iOS 16.1, *)
struct ThreadLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ThreadActivityAttributes.self) { context in
            ThreadLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("/\(context.state.currentBoard)/")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 4) {
                        if context.state.showTitle {
                            Text(context.state.currentTitle)
                                .font(.footnote)
                                .lineLimit(2)
                        }
                        if context.state.showLastComment && !context.state.latestCommentText.isEmpty {
                            Text(context.state.latestCommentText)
                                .font(.caption2)
                                .lineLimit(2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.showCommentCount {
                        Label("\(context.state.commentsCount)", systemImage: "text.bubble")
                            .font(.caption)
                    }
                }
            } compactLeading: {
                Text("/\(context.state.currentBoard)/")
                    .font(.caption2)
            } compactTrailing: {
                if context.state.showCommentCount {
                    Text("\(context.state.commentsCount)")
                        .font(.caption2)
                }
            } minimal: {
                Image(systemName: "text.bubble")
            }
        }
    }
}

@available(iOS 16.1, *)
private struct ThreadLiveActivityView: View {
    let context: ActivityViewContext<ThreadActivityAttributes>
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("/\(context.state.currentBoard)/")
                    .font(.caption)
                    .foregroundColor(.blue)
                if context.state.showCommentCount {
                    Label("\(context.state.commentsCount)", systemImage: "text.bubble")
                        .font(.caption)
                }
                Spacer()
            }
            if context.state.showTitle {
                Text(context.state.currentTitle)
                    .font(.footnote)
                    .lineLimit(2)
            }
            if context.state.showLastComment && !context.state.latestCommentText.isEmpty {
                Text(context.state.latestCommentText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
    }
}
