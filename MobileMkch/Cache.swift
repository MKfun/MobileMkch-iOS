import Foundation

class Cache {
    static let shared = Cache()
    
    private var items: [String: CacheItem] = [:]
    private let queue = DispatchQueue(label: "cache.queue", attributes: .concurrent)
    
    private init() {
        startCleanupTimer()
    }
    
    func set<T: Codable>(_ data: T, forKey key: String, ttl: TimeInterval = 300) {
        do {
            let encodedData = try JSONEncoder().encode(data)
            queue.async(flags: .barrier) {
                self.items[key] = CacheItem(
                    data: encodedData,
                    timestamp: Date(),
                    ttl: ttl
                )
            }
        } catch {
            print("Ошибка кодирования данных для кэша: \(error)")
        }
    }
    
    func get<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        return queue.sync {
            guard let item = items[key] else { return nil }
            
            if Date().timeIntervalSince(item.timestamp) > item.ttl {
                items.removeValue(forKey: key)
                return nil
            }
            
            guard let data = item.data as? Data else { return nil }
            
            do {
                return try JSONDecoder().decode(type, from: data)
            } catch {
                print("Ошибка декодирования данных из кэша: \(error)")
                return nil
            }
        }
    }
    
    func delete(_ key: String) {
        queue.async(flags: .barrier) {
            self.items.removeValue(forKey: key)
        }
    }
    
    func clear() {
        queue.async(flags: .barrier) {
            self.items.removeAll()
        }
    }
    
    private func startCleanupTimer() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            self.cleanup()
        }
    }
    
    private func cleanup() {
        queue.async(flags: .barrier) {
            let now = Date()
            self.items = self.items.filter { key, item in
                if now.timeIntervalSince(item.timestamp) > item.ttl {
                    return false
                }
                return true
            }
        }
    }
}

struct CacheItem {
    let data: Data
    let timestamp: Date
    let ttl: TimeInterval
}

extension Cache {
    func setBoards(_ boards: [Board]) {
        set(boards, forKey: "boards", ttl: 600)
    }
    
    func getBoards() -> [Board]? {
        return get([Board].self, forKey: "boards")
    }
    
    func setThreads(_ threads: [Thread], forBoard boardCode: String) {
        set(threads, forKey: "threads_\(boardCode)", ttl: 300)
    }
    
    func getThreads(forBoard boardCode: String) -> [Thread]? {
        return get([Thread].self, forKey: "threads_\(boardCode)")
    }
    
    func setThreadDetail(_ thread: ThreadDetail, forThreadId threadId: Int) {
        set(thread, forKey: "thread_detail_\(threadId)", ttl: 180)
    }
    
    func getThreadDetail(forThreadId threadId: Int) -> ThreadDetail? {
        return get(ThreadDetail.self, forKey: "thread_detail_\(threadId)")
    }
    
    func setComments(_ comments: [Comment], forThreadId threadId: Int) {
        set(comments, forKey: "comments_\(threadId)", ttl: 180)
    }
    
    func getComments(forThreadId threadId: Int) -> [Comment]? {
        return get([Comment].self, forKey: "comments_\(threadId)")
    }
} 