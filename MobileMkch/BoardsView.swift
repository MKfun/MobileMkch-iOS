import SwiftUI

struct BoardsView: View {
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var apiClient: APIClient
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @State private var boards: [Board] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            List {
            if networkMonitor.offlineEffective {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.orange)
                    Text("Оффлайн режим. Показаны сохранённые данные")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            if isLoading {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Загрузка досок...")
                        .foregroundColor(.secondary)
                }
            } else if let error = errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ошибка загрузки")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(error)
                        .font(.body)
                        .foregroundColor(.secondary)
                    Button("Повторить") {
                        loadBoards(force: true)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else {
                ForEach(boards) { board in
                    NavigationLink(destination: ThreadsView(board: board)
                        .environmentObject(settings)
                        .environmentObject(apiClient)
                        .environmentObject(NotificationManager.shared)) {
                        BoardRow(board: board)
                    }
                }
            }
            }
            .navigationTitle("Доски mkch")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                loadBoards(force: true)
            }
            .onAppear {
                if boards.isEmpty {
                    loadBoards(force: false)
                }
            }
        }
    }
    
    private func loadBoards(force: Bool) {
        isLoading = true
        errorMessage = nil
        
        apiClient.getBoards(forceReload: force) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let loadedBoards):
                    self.boards = loadedBoards
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct BoardRow: View {
    let board: Board
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let bannerURL = board.bannerURL, !settings.isBannerHidden(board.code) {
                GeometryReader { geo in
                    let width = geo.size.width
                    let height = min(max(width * 0.2, 56), 120)
                    AsyncImageView(url: bannerURL, placeholder: Image(systemName: "photo"), contentMode: .fill)
                        .frame(height: height)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .cornerRadius(8)
                }
                .frame(height: 90)
            }
            Text("/\(board.code)/")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(board.description.isEmpty ? "Без описания" : board.description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        BoardsView()
            .environmentObject(Settings())
            .environmentObject(APIClient())
    }
} 