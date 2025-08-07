import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var apiClient: APIClient
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            BoardsView()
                .environmentObject(settings)
                .environmentObject(apiClient)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Доски")
                }
                .tag(0)
            
            FavoritesView()
                .environmentObject(settings)
                .environmentObject(apiClient)
                .environmentObject(NotificationManager.shared)
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Избранное")
                }

                .tag(1)
            
            SettingsView()
                .environmentObject(settings)
                .environmentObject(apiClient)
                .tabItem {
                    Image(systemName: "gear")
                    Text("Настройки")
                }
                .tag(2)
        }
        .accentColor(.blue)
    }
}

struct FavoritesView: View {
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var apiClient: APIClient
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Group {
                if settings.favoriteThreads.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "heart")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Нет избранных тредов")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("Добавляйте треды в избранное, нажав на звездочку в списке тредов")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(settings.favoriteThreads) { favorite in
                            NavigationLink(destination: 
                                ThreadDetailView(
                                    board: Board(code: favorite.board, description: favorite.boardDescription),
                                    thread: Thread(
                                        id: favorite.id,
                                        title: favorite.title,
                                        text: "",
                                        creation: "",
                                        board: favorite.board,
                                        rating: nil,
                                        pinned: nil,
                                        files: []
                                    )
                                )
                                .environmentObject(settings)
                                .environmentObject(apiClient)
                            ) {
                                FavoriteThreadRow(favorite: favorite)
                            }
                        }
                        .onDelete(perform: deleteFavorites)
                    }
                }
            }
            .navigationTitle("Избранное")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func deleteFavorites(offsets: IndexSet) {
        for index in offsets {
            let favorite = settings.favoriteThreads[index]
            settings.removeFromFavorites(favorite.id, boardCode: favorite.board)
        }
    }
}

struct FavoriteThreadRow: View {
    let favorite: FavoriteThread
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(favorite.title)
                .font(.headline)
                .lineLimit(2)
            
            HStack {
                Text("/\(favorite.board)/")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                
                Spacer()
                
                Text(favorite.addedDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
