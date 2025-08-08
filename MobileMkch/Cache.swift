import Foundation
import CryptoKit

class Cache {
    static let shared = Cache()
    
    private var items: [String: CacheItem] = [:]
    private let queue = DispatchQueue(label: "cache.queue", attributes: .concurrent)
    private let fileManager = FileManager.default
    
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
            saveToDisk(key: key, data: encodedData, ttl: ttl)
        } catch {
            print("Ошибка кодирования данных для кэша: \(error)")
        }
    }
    
    func get<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        if let inMemory: T = queue.sync(execute: { () -> T? in
            guard let item = items[key] else { return nil }
            if Date().timeIntervalSince(item.timestamp) > item.ttl {
                items.removeValue(forKey: key)
                return nil
            }
            do { return try JSONDecoder().decode(type, from: item.data) } catch { return nil }
        }) {
            return inMemory
        }
        guard let diskItem = loadFromDisk(key: key) else { return nil }
        if Date().timeIntervalSince(diskItem.timestamp) > diskItem.ttl {
            delete(key)
            return nil
        }
        queue.async(flags: .barrier) {
            self.items[key] = diskItem
        }
        do { return try JSONDecoder().decode(type, from: diskItem.data) } catch { return nil }
    }
    
    func getStale<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        if let item = queue.sync(execute: { items[key] }) {
            return try? JSONDecoder().decode(type, from: item.data)
        }
        guard let diskItem = loadFromDisk(key: key) else { return nil }
        queue.async(flags: .barrier) {
            self.items[key] = diskItem
        }
        return try? JSONDecoder().decode(type, from: diskItem.data)
    }
    
    func delete(_ key: String) {
        queue.async(flags: .barrier) {
            self.items.removeValue(forKey: key)
        }
        deleteFromDisk(key: key)
    }
    
    func clear() {
        queue.async(flags: .barrier) {
            self.items.removeAll()
        }
        clearDisk()
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
        cleanupDisk()
    }
    
    private func cachesDirectory() -> URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }
    
    private func fileURL(forKey key: String) -> URL {
        let hash = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return cachesDirectory().appendingPathComponent("Cache_\(hash).json")
    }
    
    private func saveToDisk(key: String, data: Data, ttl: TimeInterval) {
        let item = PersistedCacheItem(data: data, timestamp: Date(), ttl: ttl)
        guard let encoded = try? JSONEncoder().encode(item) else { return }
        let url = fileURL(forKey: key)
        try? encoded.write(to: url, options: .atomic)
    }
    
    private func loadFromDisk(key: String) -> CacheItem? {
        let url = fileURL(forKey: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let persisted = try? JSONDecoder().decode(PersistedCacheItem.self, from: data) else { return nil }
        return CacheItem(data: persisted.data, timestamp: persisted.timestamp, ttl: persisted.ttl)
    }
    
    private func deleteFromDisk(key: String) {
        let url = fileURL(forKey: key)
        try? fileManager.removeItem(at: url)
    }
    
    private func clearDisk() {
        let dir = cachesDirectory()
        let contents = (try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for url in contents where url.lastPathComponent.hasPrefix("Cache_") && url.pathExtension == "json" {
            try? fileManager.removeItem(at: url)
        }
    }
    
    private func cleanupDisk() {
        let dir = cachesDirectory()
        let contents = (try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for url in contents where url.lastPathComponent.hasPrefix("Cache_") && url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let persisted = try? JSONDecoder().decode(PersistedCacheItem.self, from: data) else { continue }
            if Date().timeIntervalSince(persisted.timestamp) > persisted.ttl {
                try? fileManager.removeItem(at: url)
            }
        }
    }
}

struct CacheItem {
    let data: Data
    let timestamp: Date
    let ttl: TimeInterval
}

struct PersistedCacheItem: Codable {
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
    
    func getBoardsStale() -> [Board]? {
        return getStale([Board].self, forKey: "boards")
    }
    
    func setThreads(_ threads: [Thread], forBoard boardCode: String) {
        set(threads, forKey: "threads_\(boardCode)", ttl: 300)
    }
    
    func getThreads(forBoard boardCode: String) -> [Thread]? {
        return get([Thread].self, forKey: "threads_\(boardCode)")
    }
    
    func getThreadsStale(forBoard boardCode: String) -> [Thread]? {
        return getStale([Thread].self, forKey: "threads_\(boardCode)")
    }
    
    func setThreadDetail(_ thread: ThreadDetail, forThreadId threadId: Int) {
        set(thread, forKey: "thread_detail_\(threadId)", ttl: 180)
    }
    
    func getThreadDetail(forThreadId threadId: Int) -> ThreadDetail? {
        return get(ThreadDetail.self, forKey: "thread_detail_\(threadId)")
    }
    
    func getThreadDetailStale(forThreadId threadId: Int) -> ThreadDetail? {
        return getStale(ThreadDetail.self, forKey: "thread_detail_\(threadId)")
    }
    
    func setComments(_ comments: [Comment], forThreadId threadId: Int) {
        set(comments, forKey: "comments_\(threadId)", ttl: 180)
    }
    
    func getComments(forThreadId threadId: Int) -> [Comment]? {
        return get([Comment].self, forKey: "comments_\(threadId)")
    }
    
    func getCommentsStale(forThreadId threadId: Int) -> [Comment]? {
        return getStale([Comment].self, forKey: "comments_\(threadId)")
    }
} 
