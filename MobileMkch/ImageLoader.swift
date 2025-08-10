import SwiftUI
import Foundation
import UIKit
import ImageIO

class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var isGIF = false
    @Published var rawData: Data?
    @Published var naturalSize: CGSize? = nil
    
    private let url: String
    private let cache = ImageCache.shared
    private var cancellable: URLSessionDataTask?
    
    init(url: String) {
        self.url = url
        loadImage()
    }
    
    deinit {
        cancellable?.cancel()
    }
    
    func loadImage() {
        guard let imageURL = URL(string: url) else {
            error = NSError(domain: "Invalid URL", code: 0, userInfo: nil)
            return
        }
        
        if let cachedImage = cache.getImage(for: url) {
            self.image = cachedImage
            return
        }
        
        isLoading = true
        error = nil
        
        cancellable = URLSession.shared.dataTask(with: imageURL) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error
                    return
                }
                
                guard let data = data else {
                    self?.error = NSError(domain: "Invalid image data", code: 0, userInfo: nil)
                    return
                }
                let mime = response?.mimeType?.lowercased() ?? ""
                let isGIF = mime.contains("image/gif") || self?.url.lowercased().hasSuffix(".gif") == true
                self?.isGIF = isGIF
                if isGIF {
                    self?.rawData = data
                    self?.naturalSize = self?.extractGIFSize(from: data)
                    self?.image = nil
                } else {
                    guard let img = UIImage(data: data) else {
                        self?.error = NSError(domain: "Invalid image decode", code: 0, userInfo: nil)
                        return
                    }
                    self?.image = img
                    self?.naturalSize = img.size
                    self?.cache.setImage(img, for: self?.url ?? "")
                }
            }
        }
        
        cancellable?.resume()
    }
    
    func reload() {
        cancellable?.cancel()
        image = nil
        error = nil
        loadImage()
    }

    private func extractGIFSize(from data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return nil }
        if let w = props[kCGImagePropertyPixelWidth] as? NSNumber,
           let h = props[kCGImagePropertyPixelHeight] as? NSNumber {
            return CGSize(width: CGFloat(truncating: w), height: CGFloat(truncating: h))
        }
        if let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            return CGSize(width: cgImage.width, height: cgImage.height)
        }
        return nil
    }
}

class ImageCache {
    static let shared = ImageCache()
    
    private var cache = NSCache<NSString, UIImage>()
    private let queue = DispatchQueue(label: "image.cache.queue", attributes: .concurrent)
    
    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024
    }
    
    func setImage(_ image: UIImage, for key: String) {
        queue.async(flags: .barrier) {
            self.cache.setObject(image, forKey: key as NSString)
        }
    }
    
    func getImage(for key: String) -> UIImage? {
        return queue.sync {
            return cache.object(forKey: key as NSString)
        }
    }
    
    func clearCache() {
        queue.async(flags: .barrier) {
            self.cache.removeAllObjects()
        }
    }
}

struct AsyncImageView: View {
    let url: String
    let placeholder: Image
    let contentMode: ContentMode
    let dynamic: Bool
    let maxDynamicHeight: CGFloat?
    
    @StateObject private var loader: ImageLoader
    
    init(url: String, placeholder: Image = Image(systemName: "photo"), contentMode: ContentMode = .fit, dynamic: Bool = false, maxDynamicHeight: CGFloat? = nil) {
        self.url = url
        self.placeholder = placeholder
        self.contentMode = contentMode
        self.dynamic = dynamic
        self.maxDynamicHeight = maxDynamicHeight
        self._loader = StateObject(wrappedValue: ImageLoader(url: url))
    }
    
    var body: some View {
        Group {
            if dynamic {
                let ratio: CGFloat = {
                    if let size = loader.naturalSize, size.width > 0 { return size.height / size.width }
                    return 0.5625
                }()
                ZStack {
                    if loader.isGIF, let data = loader.rawData {
                        AnimatedGIFView(data: data, contentMode: .scaleAspectFit)
                    } else if let image = loader.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else if loader.isLoading {
                        placeholder
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(.gray)
                    } else {
                        placeholder
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(.gray)
                    }
                }
                .aspectRatio(ratio, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: maxDynamicHeight)
            } else {
                if loader.isGIF, let data = loader.rawData {
                    AnimatedGIFView(data: data, contentMode: contentMode == .fit ? .scaleAspectFit : .scaleAspectFill)
                } else if let image = loader.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                } else if loader.isLoading {
                    placeholder
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .foregroundColor(.gray)
                } else {
                    placeholder
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .foregroundColor(.gray)
                }
            }
        }
        .onTapGesture {
            if loader.error != nil {
                loader.reload()
            }
        }
    }
}

struct AnimatedGIFView: UIViewRepresentable {
    let data: Data
    let contentMode: UIView.ContentMode
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = contentMode
        imageView.clipsToBounds = true
        imageView.image = animatedImage(data: data)
        imageView.startAnimating()
        return imageView
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {
        uiView.contentMode = contentMode
        uiView.image = animatedImage(data: data)
        if !(uiView.isAnimating) {
            uiView.startAnimating()
        }
    }
    
    private func animatedImage(data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return UIImage(data: data) }
        let count = CGImageSourceGetCount(source)
        var images: [UIImage] = []
        var duration: Double = 0
        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            let frameDuration = frameDelay(for: source, index: i)
            duration += frameDuration
            images.append(UIImage(cgImage: cgImage))
        }
        if images.isEmpty { return UIImage(data: data) }
        if duration <= 0 { duration = Double(images.count) * 0.1 }
        return UIImage.animatedImage(with: images, duration: duration)
    }
    
    private func frameDelay(for source: CGImageSource, index: Int) -> Double {
        let defaultDelay = 0.1
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gifDict = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] else { return defaultDelay }
        let unclamped = gifDict[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = gifDict[kCGImagePropertyGIFDelayTime] as? Double
        let delay = unclamped ?? clamped ?? defaultDelay
        return delay < 0.011 ? 0.1 : delay
    }
}
