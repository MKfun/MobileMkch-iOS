import SwiftUI
import PhotosUI

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
    @FocusState private var isTextFocused: Bool
    @State private var pickedImages: [UIImage] = []
    @State private var showPicker: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Комментарий")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(text.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        TextEditor(text: $text)
                            .focused($isTextFocused)
                            .frame(minHeight: 120)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isTextFocused ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                            .overlay(
                                Group {
                                    if text.isEmpty {
                                        HStack {
                                            VStack {
                                                Text("Напишите ваш комментарий...")
                                                    .foregroundColor(.secondary)
                                                    .padding(.top, 20)
                                                    .padding(.leading, 16)
                                                Spacer()
                                            }
                                            Spacer()
                                        }
                                    }
                                }
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Фото")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Button {
                            showPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text("Выбрать фото")
                                Spacer()
                            }
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        if !pickedImages.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(pickedImages.enumerated()), id: \.offset) { _, img in
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 64, height: 64)
                                            .clipped()
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        Image(systemName: settings.passcode.isEmpty ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundColor(settings.passcode.isEmpty ? .orange : .green)
                        
                        Text(settings.passcode.isEmpty ? "Passcode не настроен" : "Passcode настроен")
                            .font(.caption)
                            .foregroundColor(settings.passcode.isEmpty ? .orange : .green)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    
                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(action: addComment) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "plus.circle.fill")
                            }
                            Text(isLoading ? "Отправка..." : "Добавить комментарий")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(text.isEmpty || isLoading ? Color.gray : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(25)
                        .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
                    }
                    .disabled(text.isEmpty || isLoading)
                    
                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Тред \(threadId)")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                isTextFocused = true
            }
            .alert("Успешно!", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Комментарий добавлен")
            }
            .sheet(isPresented: $showPicker) {
                ImagePickerView(selectionLimit: 4) { images in
                    pickedImages = images
                }
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
            passcode: settings.passcode,
            files: buildUploadFiles()
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

    private func buildUploadFiles() -> [UploadFile] {
        var result: [UploadFile] = []
        for (idx, img) in pickedImages.enumerated() {
            if let data = img.jpegData(compressionQuality: 0.9) {
                let file = UploadFile(
                    name: "files",
                    filename: "photo_\(idx + 1).jpg",
                    mimeType: "image/jpeg",
                    data: data
                )
                result.append(file)
            }
        }
        return result
    }
}

#Preview {
    AddCommentView(boardCode: "test", threadId: 1)
        .environmentObject(Settings())
        .environmentObject(APIClient())
} 