import Foundation
import Network
import CryptoKit
import Combine

struct UploadFile {
    let name: String
    let filename: String
    let mimeType: String
    let data: Data
}

class APIClient: ObservableObject {
    private let baseURL = "https://mkch.pooziqo.xyz"
    private let apiURL = "https://mkch.pooziqo.xyz/api"
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 40
        config.httpAdditionalHeaders = [
            "Accept": "application/json",
            "Accept-Language": Locale.preferredLanguages.first ?? "ru-RU",
            "User-Agent": self.userAgent,
            "X-Requested-With": "XMLHttpRequest"
        ]
        config.httpCookieStorage = .shared
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        return URLSession(configuration: config)
    }()
    private var authKey: String = ""
    private var passcode: String = ""
    private let userAgent = "MobileMkch/2.1.2-ios-alpha"
    private var isPowValid: Bool = false
    @Published var powSolving: Bool = false
    @Published var powProgress: Double = 0
    private var powCancelRequested: Bool = false
    
    private func sortThreads(_ threads: [Thread]) -> [Thread] {
        return threads.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned && !b.isPinned }
            if a.ratingValue != b.ratingValue { return a.ratingValue > b.ratingValue }
            return a.creationDate > b.creationDate
        }
    }
    
    func authenticate(authKey: String, completion: @escaping (Error?) -> Void) {
        self.authKey = authKey
        
        let url = URL(string: "\(baseURL)/key/auth/")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(self.userAgent, forHTTPHeaderField: "User-Agent")
        
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(error)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    completion(APIError(message: "Ошибка получения формы аутентификации", code: 0))
                    return
                }
                
                guard let data = data,
                      let html = String(data: data, encoding: .utf8) else {
                    completion(APIError(message: "Ошибка чтения формы аутентификации", code: 0))
                    return
                }
                
                let csrfToken = self.extractCSRFToken(from: html)
                
                guard !csrfToken.isEmpty else {
                    completion(APIError(message: "Не удалось извлечь CSRF токен", code: 0))
                    return
                }
                
                let boundary = "Boundary-\(UUID().uuidString)"
                var postRequest = URLRequest(url: url)
                postRequest.httpMethod = "POST"
                postRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                postRequest.setValue("\(self.baseURL)/key/auth/", forHTTPHeaderField: "Referer")
                postRequest.setValue(self.userAgent, forHTTPHeaderField: "User-Agent")
                var body = Data()
                let prefix = "--\(boundary)\r\n"
                body.append(prefix.data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"csrfmiddlewaretoken\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(csrfToken)\r\n".data(using: .utf8)!)
                body.append(prefix.data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"key\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(authKey)\r\n".data(using: .utf8)!)
                body.append("--\(boundary)--\r\n".data(using: .utf8)!)
                postRequest.httpBody = body
                
                self.session.dataTask(with: postRequest) { _, postResponse, postError in
                    DispatchQueue.main.async {
                        if let postError = postError {
                            completion(postError)
                            return
                        }
                        
                        guard let postHttpResponse = postResponse as? HTTPURLResponse,
                              (postHttpResponse.statusCode == 200 || postHttpResponse.statusCode == 302) else {
                            completion(APIError(message: "Ошибка аутентификации", code: 0))
                            return
                        }
                        
                        completion(nil)
                    }
                }.resume()
            }
        }.resume()
    }
    
    func loginWithPasscode(passcode: String, completion: @escaping (Error?) -> Void) {
        self.passcode = passcode
        
        let url = URL(string: "\(baseURL)/passcode/enter/")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(self.userAgent, forHTTPHeaderField: "User-Agent")
        
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(error)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    completion(APIError(message: "Ошибка получения формы passcode", code: 0))
                    return
                }
                
                guard let data = data,
                      let html = String(data: data, encoding: .utf8) else {
                    completion(APIError(message: "Ошибка чтения формы passcode", code: 0))
                    return
                }
                
                let csrfToken = self.extractCSRFToken(from: html)
                
                guard !csrfToken.isEmpty else {
                    completion(APIError(message: "Не удалось извлечь CSRF токен для passcode", code: 0))
                    return
                }
                
                var formData = URLComponents()
                formData.queryItems = [
                    URLQueryItem(name: "csrfmiddlewaretoken", value: csrfToken),
                    URLQueryItem(name: "passcode", value: passcode)
                ]
                
                var postRequest = URLRequest(url: url)
                postRequest.httpMethod = "POST"
                postRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                postRequest.setValue("\(self.baseURL)/passcode/enter/", forHTTPHeaderField: "Referer")
                postRequest.httpBody = formData.query?.data(using: .utf8)
                
                self.session.dataTask(with: postRequest) { _, postResponse, postError in
                    DispatchQueue.main.async {
                        if let postError = postError {
                            completion(postError)
                            return
                        }
                        
                        guard let postHttpResponse = postResponse as? HTTPURLResponse,
                              (postHttpResponse.statusCode == 200 || postHttpResponse.statusCode == 302) else {
                            completion(APIError(message: "Ошибка входа с passcode", code: 0))
                            return
                        }
                        
                        completion(nil)
                    }
                }.resume()
            }
        }.resume()
    }
    
    func getBoards(completion: @escaping (Result<[Board], Error>) -> Void) {
        if NetworkMonitor.shared.offlineEffective {
            if let cached = Cache.shared.getBoardsStale(), !cached.isEmpty {
                completion(.success(cached))
            } else {
                completion(.failure(APIError(message: "Оффлайн: нет сохранённых данных", code: 0)))
            }
            return
        }
        if let cachedBoards = Cache.shared.getBoards() {
            completion(.success(cachedBoards))
            return
        }
        
        let url = URL(string: "\(apiURL)/boards/")!
        var request = URLRequest(url: url)
        request.setValue(self.userAgent, forHTTPHeaderField: "User-Agent")
        
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    if let stale: [Board] = Cache.shared.getBoardsStale(), !stale.isEmpty {
                        completion(.success(stale))
                    } else {
                        completion(.failure(error))
                    }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                     if let stale: [Board] = Cache.shared.getBoardsStale(), !stale.isEmpty {
                         completion(.success(stale))
                     } else {
                         completion(.failure(APIError(message: "Ошибка получения досок", code: 0)))
                     }
                    return
                }
                
                guard let data = data else {
                    if let stale: [Board] = Cache.shared.getBoardsStale(), !stale.isEmpty {
                        completion(.success(stale))
                    } else {
                        completion(.failure(APIError(message: "Нет данных", code: 0)))
                    }
                    return
                }
                
                do {
                    let boards = try JSONDecoder().decode([Board].self, from: data)
                    Cache.shared.setBoards(boards)
                    completion(.success(boards))
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    func getThreads(forBoard boardCode: String, completion: @escaping (Result<[Thread], Error>) -> Void) {
        if NetworkMonitor.shared.offlineEffective {
            if let stale = Cache.shared.getThreadsStale(forBoard: boardCode), !stale.isEmpty {
                completion(.success(self.sortThreads(stale)))
            } else {
                completion(.failure(APIError(message: "Оффлайн: нет сохранённых тредов", code: 0)))
            }
            return
        }
        if let cachedThreads = Cache.shared.getThreads(forBoard: boardCode) {
            completion(.success(self.sortThreads(cachedThreads)))
            return
        }
        
        let url = URL(string: "\(apiURL)/board/\(boardCode)")!
        var request = URLRequest(url: url)
        request.setValue(self.userAgent, forHTTPHeaderField: "User-Agent")
        
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    if let stale = Cache.shared.getThreadsStale(forBoard: boardCode), !stale.isEmpty {
                        completion(.success(stale))
                    } else {
                        completion(.failure(error))
                    }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    if let stale = Cache.shared.getThreadsStale(forBoard: boardCode), !stale.isEmpty {
                        completion(.success(stale))
                    } else {
                        completion(.failure(APIError(message: "Ошибка получения тредов", code: 0)))
                    }
                    return
                }
                
                guard let data = data else {
                    if let stale = Cache.shared.getThreadsStale(forBoard: boardCode), !stale.isEmpty {
                        completion(.success(stale))
                    } else {
                        completion(.failure(APIError(message: "Нет данных", code: 0)))
                    }
                    return
                }
                
                do {
                    let threads = try JSONDecoder().decode([Thread].self, from: data)
                    let sorted = self.sortThreads(threads)
                    Cache.shared.setThreads(sorted, forBoard: boardCode)
                    completion(.success(sorted))
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    func getThreadDetail(boardCode: String, threadId: Int, completion: @escaping (Result<ThreadDetail, Error>) -> Void) {
        if NetworkMonitor.shared.offlineEffective {
            if let stale = Cache.shared.getThreadDetailStale(forThreadId: threadId) {
                completion(.success(stale))
            } else {
                completion(.failure(APIError(message: "Оффлайн: нет сохранённого треда", code: 0)))
            }
            return
        }
        if let cachedThread = Cache.shared.getThreadDetail(forThreadId: threadId) {
            completion(.success(cachedThread))
            return
        }
        
        let url = URL(string: "\(apiURL)/board/\(boardCode)/thread/\(threadId)")!
        var request = URLRequest(url: url)
        request.setValue(self.userAgent, forHTTPHeaderField: "User-Agent")
        
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    if let stale = Cache.shared.getThreadDetailStale(forThreadId: threadId) {
                        completion(.success(stale))
                    } else {
                        completion(.failure(error))
                    }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    if let stale = Cache.shared.getThreadDetailStale(forThreadId: threadId) {
                        completion(.success(stale))
                    } else {
                        completion(.failure(APIError(message: "Ошибка получения треда", code: 0)))
                    }
                    return
                }
                
                guard let data = data else {
                    if let stale = Cache.shared.getThreadDetailStale(forThreadId: threadId) {
                        completion(.success(stale))
                    } else {
                        completion(.failure(APIError(message: "Нет данных", code: 0)))
                    }
                    return
                }
                
                do {
                    let thread = try JSONDecoder().decode(ThreadDetail.self, from: data)
                    Cache.shared.setThreadDetail(thread, forThreadId: threadId)
                    completion(.success(thread))
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    func getComments(boardCode: String, threadId: Int, completion: @escaping (Result<[Comment], Error>) -> Void) {
        if NetworkMonitor.shared.offlineEffective {
            if let stale = Cache.shared.getCommentsStale(forThreadId: threadId), !stale.isEmpty {
                completion(.success(stale))
            } else {
                completion(.failure(APIError(message: "Оффлайн: нет сохранённых комментариев", code: 0)))
            }
            return
        }
        if let cachedComments = Cache.shared.getComments(forThreadId: threadId) {
            completion(.success(cachedComments))
            return
        }
        
        let url = URL(string: "\(apiURL)/board/\(boardCode)/thread/\(threadId)/comments")!
        var request = URLRequest(url: url)
        request.setValue(self.userAgent, forHTTPHeaderField: "User-Agent")
        
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    if let stale = Cache.shared.getCommentsStale(forThreadId: threadId), !stale.isEmpty {
                        completion(.success(stale))
                    } else {
                        completion(.failure(error))
                    }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    if let stale = Cache.shared.getCommentsStale(forThreadId: threadId), !stale.isEmpty {
                        completion(.success(stale))
                    } else {
                        completion(.failure(APIError(message: "Ошибка получения комментариев", code: 0)))
                    }
                    return
                }
                
                guard let data = data else {
                    if let stale = Cache.shared.getCommentsStale(forThreadId: threadId), !stale.isEmpty {
                        completion(.success(stale))
                    } else {
                        completion(.failure(APIError(message: "Нет данных", code: 0)))
                    }
                    return
                }
                
                do {
                    let comments = try JSONDecoder().decode([Comment].self, from: data)
                    Cache.shared.setComments(comments, forThreadId: threadId)
                    completion(.success(comments))
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    func getFullThread(boardCode: String, threadId: Int, completion: @escaping (Result<(ThreadDetail, [Comment]), Error>) -> Void) {
        let group = DispatchGroup()
        var threadDetail: ThreadDetail?
        var comments: [Comment]?
        var threadError: Error?
        var commentsError: Error?
        
        group.enter()
        getThreadDetail(boardCode: boardCode, threadId: threadId) { result in
            switch result {
            case .success(let detail):
                threadDetail = detail
            case .failure(let error):
                threadError = error
            }
            group.leave()
        }
        
        group.enter()
        getComments(boardCode: boardCode, threadId: threadId) { result in
            switch result {
            case .success(let commentList):
                comments = commentList
            case .failure(let error):
                commentsError = error
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            if let threadError = threadError {
                completion(.failure(threadError))
                return
            }
            
            if let commentsError = commentsError {
                completion(.failure(commentsError))
                return
            }
            
            guard let detail = threadDetail, let commentList = comments else {
                completion(.failure(APIError(message: "Не удалось загрузить данные", code: 0)))
                return
            }
            
            completion(.success((detail, commentList)))
        }
    }
    
    func createThread(boardCode: String, title: String, text: String, passcode: String, files: [UploadFile] = [], completion: @escaping (Error?) -> Void) {
        if !passcode.isEmpty {
            loginWithPasscode(passcode: passcode) { error in
                if let error = error {
                    completion(error)
                    return
                }
                self.performCreateThread(boardCode: boardCode, title: title, text: text, files: files, completion: completion)
            }
        } else {
            self.ensurePowValidated { powError in
                if let powError = powError {
                    completion(powError)
                    return
                }
                self.performCreateThread(boardCode: boardCode, title: title, text: text, files: files, completion: completion)
            }
        }
    }
    
    private func performCreateThread(boardCode: String, title: String, text: String, files: [UploadFile] = [], completion: @escaping (Error?) -> Void) {
        let formURL = "\(baseURL)/boards/board/\(boardCode)/new"
        let url = URL(string: formURL)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(self.userAgent, forHTTPHeaderField: "User-Agent")
        
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(error)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    completion(APIError(message: "Ошибка получения формы", code: 0))
                    return
                }
                
                guard let data = data,
                      let html = String(data: data, encoding: .utf8) else {
                    completion(APIError(message: "Ошибка чтения формы", code: 0))
                    return
                }
                
                let csrfToken = self.extractCSRFToken(from: html)
                
                guard !csrfToken.isEmpty else {
                    completion(APIError(message: "Не удалось извлечь CSRF токен", code: 0))
                    return
                }
                
                var postRequest = URLRequest(url: url)
                postRequest.httpMethod = "POST"
                postRequest.setValue(formURL, forHTTPHeaderField: "Referer")
                postRequest.setValue(self.userAgent, forHTTPHeaderField: "User-Agent")

                if files.isEmpty {
                    var formData = URLComponents()
                    formData.queryItems = [
                        URLQueryItem(name: "csrfmiddlewaretoken", value: csrfToken),
                        URLQueryItem(name: "title", value: title),
                        URLQueryItem(name: "text", value: text)
                    ]
                    postRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                    postRequest.httpBody = formData.query?.data(using: .utf8)
                } else {
                    let boundary = "Boundary-\(UUID().uuidString)"
                    postRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                    let body = self.buildMultipartBody(parameters: [
                        "csrfmiddlewaretoken": csrfToken,
                        "title": title,
                        "text": text
                    ], files: files, boundary: boundary)
                    postRequest.httpBody = body
                }
                
                self.session.dataTask(with: postRequest) { _, postResponse, postError in
                    DispatchQueue.main.async {
                        if let postError = postError {
                            completion(postError)
                            return
                        }
                        
                        guard let postHttpResponse = postResponse as? HTTPURLResponse,
                              (postHttpResponse.statusCode == 200 || postHttpResponse.statusCode == 302) else {
                            completion(APIError(message: "Ошибка создания треда", code: 0))
                            return
                        }
                        
                        Cache.shared.delete("threads_\(boardCode)")
                        completion(nil)
                    }
                }.resume()
            }
        }.resume()
    }
    
    func addComment(boardCode: String, threadId: Int, text: String, passcode: String, files: [UploadFile] = [], completion: @escaping (Error?) -> Void) {
        if !passcode.isEmpty {
            loginWithPasscode(passcode: passcode) { error in
                if let error = error {
                    completion(error)
                    return
                }
                self.performAddComment(boardCode: boardCode, threadId: threadId, text: text, files: files, completion: completion)
            }
        } else {
            self.ensurePowValidated { powError in
                if let powError = powError {
                    completion(powError)
                    return
                }
                self.performAddComment(boardCode: boardCode, threadId: threadId, text: text, files: files, completion: completion)
            }
        }
    }
    
    private func performAddComment(boardCode: String, threadId: Int, text: String, files: [UploadFile] = [], completion: @escaping (Error?) -> Void) {
        let formURL = "\(baseURL)/boards/board/\(boardCode)/thread/\(threadId)/comment"
        let url = URL(string: formURL)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(self.userAgent, forHTTPHeaderField: "User-Agent")
        
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(error)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    completion(APIError(message: "Ошибка получения формы", code: 0))
                    return
                }
                
                guard let data = data,
                      let html = String(data: data, encoding: .utf8) else {
                    completion(APIError(message: "Ошибка чтения формы", code: 0))
                    return
                }
                
                let csrfToken = self.extractCSRFToken(from: html)
                
                guard !csrfToken.isEmpty else {
                    completion(APIError(message: "Не удалось извлечь CSRF токен", code: 0))
                    return
                }
                
                var postRequest = URLRequest(url: url)
                postRequest.httpMethod = "POST"
                postRequest.setValue(formURL, forHTTPHeaderField: "Referer")
                postRequest.setValue(self.userAgent, forHTTPHeaderField: "User-Agent")

                if files.isEmpty {
                    var formData = URLComponents()
                    formData.queryItems = [
                        URLQueryItem(name: "csrfmiddlewaretoken", value: csrfToken),
                        URLQueryItem(name: "text", value: text)
                    ]
                    postRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                    postRequest.httpBody = formData.query?.data(using: .utf8)
                } else {
                    let boundary = "Boundary-\(UUID().uuidString)"
                    postRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                    let body = self.buildMultipartBody(parameters: [
                        "csrfmiddlewaretoken": csrfToken,
                        "text": text
                    ], files: files, boundary: boundary)
                    postRequest.httpBody = body
                }
                
                self.session.dataTask(with: postRequest) { _, postResponse, postError in
                    DispatchQueue.main.async {
                        if let postError = postError {
                            completion(postError)
                            return
                        }
                        
                        guard let postHttpResponse = postResponse as? HTTPURLResponse,
                              (postHttpResponse.statusCode == 200 || postHttpResponse.statusCode == 302) else {
                            completion(APIError(message: "Ошибка добавления комментария", code: 0))
                            return
                        }
                        
                        Cache.shared.delete("comments_\(threadId)")
                        completion(nil)
                    }
                }.resume()
            }
        }.resume()
    }
    
    private func extractCSRFToken(from html: String) -> String {
        let pattern = #"name=['"]csrfmiddlewaretoken['"]\s+value=['"]([^'"]+)['"]"#
        let regex = try? NSRegularExpression(pattern: pattern)
        
        guard let match = regex?.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)) else {
            return ""
        }
        
        guard let range = Range(match.range(at: 1), in: html) else {
            return ""
        }
        
        return String(html[range])
    }
    
    private func buildMultipartBody(parameters: [String: String], files: [UploadFile], boundary: String) -> Data {
        var body = Data()
        let boundaryPrefix = "--\(boundary)\r\n"
        for (key, value) in parameters {
            body.append(boundaryPrefix.data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        for file in files {
            body.append(boundaryPrefix.data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(file.filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(file.mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(file.data)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }

    private struct PoWChallengeDTO: Codable { let challenge: String; let difficulty: Int }

    private func ensurePowValidated(completion: @escaping (Error?) -> Void) {
        if isPowValid { completion(nil); return }
        powCancelRequested = false
        powSolving = true
        powProgress = 0
        getPowChallenge { result in
            switch result {
            case .failure(let e): completion(e)
            case .success(let dto):
                self.solvePow(challenge: dto.challenge, difficulty: dto.difficulty) { solveResult in
                    switch solveResult {
                    case .failure(let e): completion(e)
                    case .success(let solution):
                        self.validatePow(challenge: dto.challenge, nonce: solution.nonce, response: solution.response, elapsed: solution.elapsed) { valError in
                            if valError == nil { self.isPowValid = true }
                            self.powSolving = false
                            self.powProgress = valError == nil ? 1.0 : 0.0
                            completion(valError)
                        }
                    }
                }
            }
        }
    }

    private func getPowChallenge(completion: @escaping (Result<PoWChallengeDTO, Error>) -> Void) {
        let url = URL(string: "\(baseURL)/pow/challenge/")!
        var request = URLRequest(url: url)
        request.setValue(self.userAgent, forHTTPHeaderField: "User-Agent")
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error { completion(.failure(error)); return }
                guard let http = response as? HTTPURLResponse, http.statusCode == 200, let data = data else {
                    completion(.failure(APIError(message: "PoW challenge error", code: 0)))
                    return
                }
                do {
                    let dto = try JSONDecoder().decode(PoWChallengeDTO.self, from: data)
                    completion(.success(dto))
                } catch { completion(.failure(error)) }
            }
        }.resume()
    }

    private func sha256Hex(_ string: String) -> String {
        let data = Data(string.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func solvePow(challenge: String, difficulty: Int, completion: @escaping (Result<(nonce: String, response: String, elapsed: Double), Error>) -> Void) {
        let targetPrefix = String(repeating: "0", count: difficulty)
        let start = Date()
        DispatchQueue.global(qos: .userInitiated).async {
            var counter: UInt64 = 0
            var responseHex = ""
            var nonceFound = ""
            var lastProgressTick: UInt64 = 0
            while true {
                if self.powCancelRequested {
                    break
                }
                let nonce = String(counter)
                let resp = self.sha256Hex("\(challenge)\(nonce)")
                if resp.hasPrefix(targetPrefix) {
                    responseHex = resp
                    nonceFound = nonce
                    break
                }
                counter &+= 1
                if counter % 50000 == 0 {
                    if Date().timeIntervalSince(start) > 60 {
                        break
                    }
                }
                if counter - lastProgressTick >= 20000 {
                    lastProgressTick = counter
                    let elapsed = Date().timeIntervalSince(start)
                    var p = min(0.9, elapsed / 60.0)
                    if p.isNaN || p.isInfinite { p = 0 }
                    DispatchQueue.main.async { self.powProgress = p }
                }
            }
            let elapsed = Date().timeIntervalSince(start)
            DispatchQueue.main.async {
                if self.powCancelRequested {
                    self.powSolving = false
                    self.powProgress = 0
                    completion(.failure(APIError(message: "PoW canceled", code: 0)))
                } else if nonceFound.isEmpty {
                    self.powSolving = false
                    self.powProgress = 0
                    completion(.failure(APIError(message: "PoW timeout", code: 0)))
                } else {
                    completion(.success((nonce: nonceFound, response: responseHex, elapsed: elapsed)))
                }
            }
        }
    }

    func cancelPow() {
        powCancelRequested = true
    }

    private func validatePow(challenge: String, nonce: String, response: String, elapsed: Double, completion: @escaping (Error?) -> Void) {
        let url = URL(string: "\(baseURL)/pow/validate/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(self.userAgent, forHTTPHeaderField: "User-Agent")
        let payload: [String: Any] = [
            "challenge": challenge,
            "nonce": nonce,
            "response": response,
            "elapsedTime": elapsed,
            "meta": [
                "hasWorkers": false,
                "hasCrypto": true,
                "threads": 1,
                "mode": "single",
                "reason": "ios"
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error { completion(error); return }
                guard let http = response as? HTTPURLResponse else { completion(APIError(message: "PoW validate error", code: 0)); return }
                if (200...299).contains(http.statusCode) {
                    completion(nil)
                } else {
                    completion(APIError(message: "PoW invalid", code: http.statusCode))
                }
            }
        }.resume()
    }

    func checkNewThreads(forBoard boardCode: String, lastKnownThreadId: Int, completion: @escaping (Result<[Thread], Error>) -> Void) {
        let url = URL(string: "\(apiURL)/board/\(boardCode)")!
        var request = URLRequest(url: url)
        request.setValue(self.userAgent, forHTTPHeaderField: "User-Agent")
        
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    completion(.failure(APIError(message: "Ошибка получения тредов", code: 0)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(APIError(message: "Нет данных", code: 0)))
                    return
                }
                
                do {
                    let currentThreads = try JSONDecoder().decode([Thread].self, from: data)
                    
                    let savedThreadsKey = "savedThreads_\(boardCode)"
                    let savedThreadsData = UserDefaults.standard.data(forKey: savedThreadsKey)
                    
                    if let savedThreadsData = savedThreadsData,
                       let savedThreads = try? JSONDecoder().decode([Thread].self, from: savedThreadsData) {
                        
                        let savedThreadIds = Set(savedThreads.map { $0.id })
                        let newThreads = currentThreads.filter { !savedThreadIds.contains($0.id) }
                        
                        if !newThreads.isEmpty {
                            print("Найдено \(newThreads.count) новых тредов в /\(boardCode)/")
                        }
                        
                        completion(.success(newThreads))
                    } else {
                        print("Первая синхронизация для /\(boardCode)/ - сохраняем \(currentThreads.count) тредов")
                        completion(.success([]))
                    }
                    
                    if let encodedData = try? JSONEncoder().encode(currentThreads) {
                        UserDefaults.standard.set(encodedData, forKey: savedThreadsKey)
                    }
                    
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
} 