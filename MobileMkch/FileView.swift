import SwiftUI
import AVKit
import QuickLook
import AVFoundation

struct FileView: View {
    let fileInfo: FileInfo
    @State private var showingFullScreen = false
    @State private var showVideoPlayer = false
    @State private var showQuickLook = false
    @State private var videoThumbnail: UIImage? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if fileInfo.isImage {
                ZStack {
                    AsyncImageView(url: fileInfo.url, contentMode: .fill, enableRetryTap: false)
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipped()
                }
                .contentShape(Rectangle())
                .onTapGesture { showingFullScreen = true }
            } else if fileInfo.isVideo {
                ZStack {
                    if let image = videoThumbnail {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 160)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 160)
                            .overlay(
                                ProgressView()
                            )
                    }
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white)
                        .shadow(radius: 6)
                }
                .frame(maxWidth: .infinity)
                .cornerRadius(10)
                .contentShape(Rectangle())
                .onTapGesture { showVideoPlayer = true }
                .task {
                    if videoThumbnail == nil {
                        videoThumbnail = await VideoThumbnailGenerator.shared.generateThumbnail(from: fileInfo.url)
                    }
                }
            } else {
                HStack {
                    Image(systemName: "doc")
                        .foregroundColor(.blue)
                    Text(fileInfo.filename)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .contentShape(Rectangle())
                .onTapGesture { showQuickLook = true }
            }
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
            if fileInfo.isImage {
                NativeFullScreenImageView(url: fileInfo.url)
            }
        }
        .fullScreenCover(isPresented: $showVideoPlayer) {
            if let url = URL(string: fileInfo.url) {
                VideoPlayerFullScreenView(url: url)
            }
        }
        .sheet(isPresented: $showQuickLook) {
            if let url = URL(string: fileInfo.url) {
                QuickLookPreview(url: url)
            }
        }
    }
}

struct NativeFullScreenImageView: View {
    let url: String
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset = CGSize.zero
    @State private var lastOffset = CGSize.zero
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    @State private var showUI = true
    @State private var showSaveAlert = false
    @State private var saveMessage = ""
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            GeometryReader { geometry in
                AsyncImageView(url: url, contentMode: .fit, enableRetryTap: false)
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                    .clipped()
                    .scaleEffect(scale)
                    .offset(offset)
                    .opacity(isDragging ? 0.8 : 1.0)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale = min(max(scale * delta, 0.5), 5)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                if scale < 1 {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        scale = 1
                                        offset = .zero
                                    }
                                }
                            }
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if scale > 1 {
                                    let delta = CGSize(
                                        width: value.translation.width - lastOffset.width,
                                        height: value.translation.height - lastOffset.height
                                    )
                                    lastOffset = value.translation
                                    offset = CGSize(
                                        width: offset.width + delta.width,
                                        height: offset.height + delta.height
                                    )
                                } else {
                                    dragOffset = value.translation
                                    isDragging = true
                                }
                            }
                            .onEnded { value in
                                if scale <= 1 {
                                    if abs(dragOffset.height) > 100 || abs(dragOffset.width) > 100 {
                                        dismiss()
                                    } else {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            dragOffset = .zero
                                        }
                                    }
                                    isDragging = false
                                }
                                lastOffset = CGSize.zero
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if scale > 1 {
                                scale = 1
                                offset = .zero
                            } else {
                                scale = 2
                            }
                        }
                    }
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showUI.toggle()
                        }
                    }
            }
        }
        .overlay(
            VStack {
                if showUI {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        Button(action: { saveCurrentImage() }) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }
                    .padding()
                    .transition(.opacity)
                }
                
                Spacer()
            }
        )
        .animation(.easeInOut(duration: 0.2), value: showUI)
        .alert(isPresented: $showSaveAlert) {
            Alert(title: Text(saveMessage))
        }
    }

    private func saveCurrentImage() {
        guard let imageURL = URL(string: url) else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: imageURL)
                if let uiImage = UIImage(data: data) {
                    UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
                    saveMessage = "Сохранено в Фото"
                    showSaveAlert = true
                } else {
                    saveMessage = "Не удалось сохранить"
                    showSaveAlert = true
                }
            } catch {
                saveMessage = "Ошибка сохранения"
                showSaveAlert = true
            }
        }
    }
}

struct FilesView: View {
    let files: [String]
    
    var body: some View {
        if !files.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Файлы (\(files.count))")
                    .font(.headline)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(files, id: \.self) { file in
                        FileView(fileInfo: FileInfo(filePath: file))
                    }
                }
            }
        }
    }
}
