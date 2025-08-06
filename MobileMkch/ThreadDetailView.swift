import SwiftUI

struct ThreadDetailView: View {
    let board: Board
    let thread: Thread
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var apiClient: APIClient
    @State private var threadDetail: ThreadDetail?
    @State private var comments: [Comment] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddComment = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Загрузка треда...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else if let error = errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ошибка загрузки")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text(error)
                            .font(.body)
                            .foregroundColor(.secondary)
                        Button("Повторить") {
                            loadThreadDetail()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else if let detail = threadDetail {
                    ThreadContentView(thread: detail, showFiles: settings.showFiles)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Комментарии (\(comments.count))")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button("Добавить") {
                                showingAddComment = true
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        if comments.isEmpty {
                            Text("Комментариев пока нет")
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            LazyVStack(alignment: .leading, spacing: 16) {
                                ForEach(comments) { comment in
                                    CommentView(comment: comment, showFiles: settings.showFiles)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("#\(thread.id)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Обновить") {
                    loadThreadDetail()
                }
            }
        }
        .sheet(isPresented: $showingAddComment) {
            AddCommentView(boardCode: board.code, threadId: thread.id)
                .environmentObject(settings)
                .environmentObject(apiClient)
        }
        .onAppear {
            if threadDetail == nil {
                loadThreadDetail()
            }
        }
    }
    
    private func loadThreadDetail() {
        isLoading = true
        errorMessage = nil
        
        apiClient.getFullThread(boardCode: board.code, threadId: thread.id) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let (detail, loadedComments)):
                    self.threadDetail = detail
                    self.comments = loadedComments
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct ThreadContentView: View {
    let thread: ThreadDetail
    let showFiles: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(thread.title)
                .font(.title2)
                .fontWeight(.bold)
            
            HStack {
                Text(thread.creationDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            if showFiles && !thread.files.isEmpty {
                FilesView(files: thread.files)
            }
            
            if !thread.text.isEmpty {
                Text(thread.text)
                    .font(.body)
            }
        }
    }
}

struct CommentView: View {
    let comment: Comment
    let showFiles: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ID: \(comment.id)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(comment.creationDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if showFiles && !comment.files.isEmpty {
                FilesView(files: comment.files)
            }
            
            if !comment.text.isEmpty {
                Text(comment.formattedText)
                    .font(.body)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct FilesView: View {
    let files: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "paperclip")
                    .foregroundColor(.blue)
                Text("Файлы (\(files.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(files, id: \.self) { filePath in
                    FileButton(fileInfo: FileInfo(filePath: filePath))
                }
            }
        }
    }
}

struct FileButton: View {
    let fileInfo: FileInfo
    
    var body: some View {
        Button(action: {
            if let url = URL(string: fileInfo.url) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack {
                Image(systemName: fileIcon)
                    .foregroundColor(fileColor)
                Text(fileInfo.filename)
                    .font(.caption)
                    .lineLimit(1)
                Spacer()
            }
            .padding(8)
            .background(Color(.systemGray5))
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var fileIcon: String {
        if fileInfo.isImage {
            return "photo"
        } else if fileInfo.isVideo {
            return "video"
        } else {
            return "doc"
        }
    }
    
    private var fileColor: Color {
        if fileInfo.isImage {
            return .green
        } else if fileInfo.isVideo {
            return .red
        } else {
            return .blue
        }
    }
}

#Preview {
    NavigationView {
        ThreadDetailView(
            board: Board(code: "test", description: "Test board"),
            thread: Thread(id: 1, title: "Test Thread", text: "Test content", creation: "2023-01-01T00:00:00Z", board: "test", rating: nil, pinned: nil, files: [])
        )
        .environmentObject(Settings())
        .environmentObject(APIClient())
    }
} 