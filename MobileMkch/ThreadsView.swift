import SwiftUI

struct ThreadsView: View {
    let board: Board
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var apiClient: APIClient
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var threads: [Thread] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentPage = 0
    @State private var showingCreateThread = false
    
    private var pageSize: Int { settings.pageSize }
    private var totalPages: Int { (threads.count + pageSize - 1) / pageSize }
    private var currentThreads: [Thread] {
        let start = currentPage * pageSize
        let end = min(start + pageSize, threads.count)
        return Array(threads[start..<end])
    }
    
    var body: some View {
        VStack {
            if isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Загрузка тредов...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ошибка загрузки")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(error)
                        .font(.body)
                        .foregroundColor(.secondary)
                    Button("Повторить") {
                        loadThreads()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else {
                List {
                    ForEach(currentThreads) { thread in
                        NavigationLink(destination: ThreadDetailView(board: board, thread: thread)
                            .environmentObject(settings)
                            .environmentObject(apiClient)) {
                            ThreadRow(thread: thread, showFiles: settings.showFiles)
                        }
                    }
                }
                
                if totalPages > 1 {
                    HStack {
                        Button("←") {
                            if currentPage > 0 {
                                currentPage -= 1
                            }
                        }
                        .disabled(currentPage == 0)
                        
                        Spacer()
                        
                        Text("Страница \(currentPage + 1) из \(totalPages)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("→") {
                            if currentPage < totalPages - 1 {
                                currentPage += 1
                            }
                        }
                        .disabled(currentPage >= totalPages - 1)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("/\(board.code)/")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Создать") {
                    showingCreateThread = true
                }
            }
        }
        .sheet(isPresented: $showingCreateThread) {
            CreateThreadView(boardCode: board.code)
                .environmentObject(settings)
                .environmentObject(apiClient)
        }
        .onAppear {
            settings.lastBoard = board.code
            settings.saveSettings()
            
            if threads.isEmpty {
                loadThreads()
            }
        }
    }
    
    private func loadThreads() {
        isLoading = true
        errorMessage = nil
        
        apiClient.getThreads(forBoard: board.code) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let loadedThreads):
                    self.threads = loadedThreads
                    self.currentPage = 0
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct ThreadRow: View {
    let thread: Thread
    let showFiles: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("#\(thread.id): \(thread.title)")
                    .font(.headline)
                    .lineLimit(2)
                
                Spacer()
                
                if thread.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.orange)
                }
            }
            
            HStack {
                Text(thread.creationDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if thread.ratingValue > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("\(thread.ratingValue)")
                            .font(.caption)
                    }
                }
                
                if showFiles && !thread.files.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "paperclip")
                            .foregroundColor(.blue)
                        Text("\(thread.files.count)")
                            .font(.caption)
                    }
                }
                
                Spacer()
            }
            
            if !thread.text.isEmpty {
                Text(thread.text)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        ThreadsView(board: Board(code: "test", description: "Test board"))
            .environmentObject(Settings())
            .environmentObject(APIClient())
    }
} 