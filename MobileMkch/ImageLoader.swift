import SwiftUI
import Foundation

class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    @Published var error: Error?
    
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
                
                guard let data = data, let image = UIImage(data: data) else {
                    self?.error = NSError(domain: "Invalid image data", code: 0, userInfo: nil)
                    return
                }
                
                self?.image = image
                self?.cache.setImage(image, for: self?.url ?? "")
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
    let enableRetryTap: Bool
    
    @StateObject private var loader: ImageLoader
    
    init(url: String, placeholder: Image = Image(systemName: "photo"), contentMode: ContentMode = .fit, enableRetryTap: Bool = true) {
        self.url = url
        self.placeholder = placeholder
        self.contentMode = contentMode
        self.enableRetryTap = enableRetryTap
        self._loader = StateObject(wrappedValue: ImageLoader(url: url))
    }
    
    var body: some View {
        let content = Group {
            if let image = loader.image {
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
        if enableRetryTap {
            content
                .onTapGesture {
                    if loader.error != nil {
                        loader.reload()
                    }
                }
        } else {
            content
        }
    }
}
