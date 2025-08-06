import SwiftUI

struct AddCommentView: View {
    let boardCode: String
    let threadId: Int
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var apiClient: APIClient
    @Environment(\.dismiss) private var dismiss
    
    @State private var text = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Текст комментария", text: $text)
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
            .navigationTitle("Комментарий в тред \(threadId)")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
            .navigationBarItems(
                leading: Button("Отмена") {
                    dismiss()
                },
                trailing: Button("Добавить") {
                    addComment()
                }
                .disabled(text.isEmpty || isLoading)
            )
            .overlay {
                if isLoading {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Добавление комментария...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                }
            }
            .alert("Комментарий добавлен", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Комментарий успешно добавлен")
            }
        }
    }
    
    private func addComment() {
        guard !text.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        apiClient.addComment(
            boardCode: boardCode,
            threadId: threadId,
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
    AddCommentView(boardCode: "test", threadId: 1)
        .environmentObject(Settings())
        .environmentObject(APIClient())
} 