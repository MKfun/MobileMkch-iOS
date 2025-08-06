import SwiftUI

struct CreateThreadView: View {
    let boardCode: String
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var apiClient: APIClient
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var text = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Заголовок треда", text: $title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Текст треда", text: $text)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(minHeight: 100)
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
                
                Section {
                    if !settings.passcode.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Passcode настроен")
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading) {
                                Text("Passcode не настроен")
                                    .foregroundColor(.orange)
                                Text("Постинг может быть ограничен")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Создать тред /\(boardCode)/")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Отмена") {
                    dismiss()
                },
                trailing: Button("Создать") {
                    createThread()
                }
                .disabled(title.isEmpty || text.isEmpty || isLoading)
            )
            .overlay {
                if isLoading {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Создание треда...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                }
            }
            .alert("Тред создан", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Тред успешно создан")
            }
        }
    }
    
    private func createThread() {
        guard !title.isEmpty && !text.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        apiClient.createThread(
            boardCode: boardCode,
            title: title,
            text: text,
            passcode: settings.passcode
        ) { error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                } else {
                    self.showingSuccess = true
                }
            }
        }
    }
}

#Preview {
    CreateThreadView(boardCode: "test")
        .environmentObject(Settings())
        .environmentObject(APIClient())
} 