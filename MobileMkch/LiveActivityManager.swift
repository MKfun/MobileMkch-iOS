import Foundation
import ActivityKit

@available(iOS 16.1, *)
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private let storeKey = "activeThreadActivities"
    private var threadIdToActivityId: [Int: String] = [:]
    private var tickerTask: Task<Void, Never>?
    private var tickerActivityId: String?

    private init() {
        load()
    }

    func isActive(threadId: Int) -> Bool {
        return threadIdToActivityId[threadId] != nil && activity(for: threadId) != nil
    }

    func start(for detail: ThreadDetail, comments: [Comment], settings: Settings) {
        let latestText = comments.last?.formattedText ?? ""
        let count = comments.count

        let attributes = ThreadActivityAttributes(threadId: detail.id, title: detail.title, board: detail.board)
        let state = ThreadActivityAttributes.ContentState(
            latestCommentText: latestText,
            commentsCount: count,
            showTitle: settings.liveActivityShowTitle,
            showLastComment: settings.liveActivityShowLastComment,
            showCommentCount: settings.liveActivityShowCommentCount,
            currentTitle: detail.title,
            currentBoard: detail.board
        )

        do {
            let activity = try Activity<ThreadActivityAttributes>.request(attributes: attributes, contentState: state, pushType: nil)
            threadIdToActivityId[detail.id] = activity.id
            save()
        } catch {
        }
    }

    func update(threadId: Int, comments: [Comment], settings: Settings) {
        guard let activity = activity(for: threadId) else { return }
        let latestText = comments.last?.formattedText ?? ""
        let count = comments.count
        let state = ThreadActivityAttributes.ContentState(
            latestCommentText: latestText,
            commentsCount: count,
            showTitle: settings.liveActivityShowTitle,
            showLastComment: settings.liveActivityShowLastComment,
            showCommentCount: settings.liveActivityShowCommentCount,
            currentTitle: "",
            currentBoard: ""
        )
        Task {
            await activity.update(using: state)
        }
    }

    func end(threadId: Int) {
        guard let activity = activity(for: threadId) else { return }
        Task {
            await activity.end(dismissalPolicy: .immediate)
        }
        threadIdToActivityId.removeValue(forKey: threadId)
        save()
    }

    private func activity(for threadId: Int) -> Activity<ThreadActivityAttributes>? {
        guard let id = threadIdToActivityId[threadId] else { return nil }
        return Activity<ThreadActivityAttributes>.activities.first(where: { $0.id == id })
    }

    private func save() {
        if let data = try? JSONEncoder().encode(threadIdToActivityId) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storeKey),
           let map = try? JSONDecoder().decode([Int: String].self, from: data) {
            threadIdToActivityId = map
        }
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
extension LiveActivityManager {
    var isTickerRunning: Bool { tickerTask != nil }

    func startTicker(settings: Settings, apiClient: APIClient) {
        stopTicker()
        let attributes = ThreadActivityAttributes(threadId: -1, title: "", board: "")
        let initial = ThreadActivityAttributes.ContentState(
            latestCommentText: "",
            commentsCount: 0,
            showTitle: settings.liveActivityShowTitle,
            showLastComment: settings.liveActivityShowLastComment,
            showCommentCount: settings.liveActivityShowCommentCount,
            currentTitle: "",
            currentBoard: ""
        )
        do {
            let activity = try Activity<ThreadActivityAttributes>.request(attributes: attributes, contentState: initial, pushType: nil)
            tickerActivityId = activity.id
        } catch {
            return
        }
        tickerTask = Task { [weak self] in
            while !(Task.isCancelled) {
                guard let self = self, let activityId = self.tickerActivityId,
                      let activity = Activity<ThreadActivityAttributes>.activities.first(where: { $0.id == activityId }) else { break }
                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    let boardHandler: (String) -> Void = { boardCode in
                        apiClient.getThreads(forBoard: boardCode) { result in
                            switch result {
                            case .success(let threads):
                                guard let thread = threads.randomElement() else {
                                    cont.resume()
                                    return
                                }
                                apiClient.getFullThread(boardCode: boardCode, threadId: thread.id) { full in
                                    switch full {
                                    case .success(let (detail, comments)):
                                        let text = comments.last?.formattedText ?? detail.text
                                        let count = comments.count
                                        let state = ThreadActivityAttributes.ContentState(
                                            latestCommentText: text,
                                            commentsCount: count,
                                            showTitle: settings.liveActivityShowTitle,
                                            showLastComment: settings.liveActivityShowLastComment,
                                            showCommentCount: settings.liveActivityShowCommentCount,
                                            currentTitle: detail.title,
                                            currentBoard: detail.board
                                        )
                                        Task { await activity.update(using: state) }
                                        cont.resume()
                                    case .failure:
                                        cont.resume()
                                    }
                                }
                            case .failure:
                                cont.resume()
                            }
                        }
                    }
                    if settings.liveActivityTickerRandomBoard {
                        apiClient.getBoards { boardsResult in
                            switch boardsResult {
                            case .success(let boards):
                                if let random = boards.randomElement() {
                                    boardHandler(random.code)
                                } else {
                                    cont.resume()
                                }
                            case .failure:
                                cont.resume()
                            }
                        }
                    } else {
                        let code = settings.liveActivityTickerBoardCode.isEmpty ? settings.lastBoard : settings.liveActivityTickerBoardCode
                        boardHandler(code)
                    }
                }
                try? await Task.sleep(nanoseconds: UInt64(max(settings.liveActivityTickerInterval, 5)) * 1_000_000_000)
            }
        }
    }

    func stopTicker() {
        tickerTask?.cancel()
        tickerTask = nil
        if let id = tickerActivityId,
           let activity = Activity<ThreadActivityAttributes>.activities.first(where: { $0.id == id }) {
            Task { await activity.end(dismissalPolicy: .immediate) }
        }
        tickerActivityId = nil
    }
}


