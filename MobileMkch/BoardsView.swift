import SwiftUI

struct BoardsView: View {
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var apiClient: APIClient
    @State private var boards: [Board] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSettings = false
    
    var body: some View {
        List {
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
                        loadBoards()
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
        .onAppear {
            if boards.isEmpty {
                loadBoards()
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(apiClient)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gearshape")
                }
            }
        }
    }
    
    private func loadBoards() {
        isLoading = true
        errorMessage = nil
        
        apiClient.getBoards { result in
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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