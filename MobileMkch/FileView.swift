import SwiftUI

struct FileView: View {
    let fileInfo: FileInfo
    var dynamic: Bool = false
    @State private var showingFullScreen = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if fileInfo.isImage {
                if dynamic {
                    if fileInfo.isGIF {
                        AsyncImageView(url: fileInfo.url, contentMode: .fit, dynamic: true)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .contentShape(Rectangle())
                            .onTapGesture { showingFullScreen = true }
                    } else {
                        AsyncImageView(url: fileInfo.url, contentMode: .fit, dynamic: false)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .contentShape(Rectangle())
                            .onTapGesture { showingFullScreen = true }
                    }
                } else {
                    AsyncImageView(url: fileInfo.url, contentMode: .fit, dynamic: false)
                        .frame(maxHeight: 200)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture { showingFullScreen = true }
                }
            } else if fileInfo.isVideo {
                VStack {
                    Image(systemName: "play.rectangle")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text(fileInfo.filename)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 100)
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
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
            }
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
            if fileInfo.isImage {
                NativeFullScreenImageView(url: fileInfo.url)
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
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            GeometryReader { geometry in
                AsyncImageView(url: url, contentMode: .fit, dynamic: true)
                    .frame(width: geometry.size.width)
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
                    .highPriorityGesture(
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
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                scale = 1
                                offset = .zero
                            }
                        }) {
                            Image(systemName: "arrow.counterclockwise")
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
    }
}

struct FilesView: View {
    let files: [String]
    var dynamic: Bool = false
    
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
                        FileView(fileInfo: FileInfo(filePath: file), dynamic: dynamic)
                    }
                }
            }
        }
    }
}
