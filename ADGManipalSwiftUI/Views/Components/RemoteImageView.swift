import SwiftUI
import UIKit
import ImageIO

struct RemoteImageView: View {
    var urlString: String?
    var aspectRatio: CGFloat = 1
    @State private var loadedImage: UIImage?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            if let loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    ADGTheme.surface
                    Rectangle()
                        .stroke(ADGTheme.hairline, lineWidth: 1)
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .aspectRatio(aspectRatio, contentMode: .fill)
        .contentShape(Rectangle())
        .clipped()
        .task(id: urlString) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard !isLoading else { return }
        guard let urlString, let url = URL(string: urlString) else {
            await MainActor.run { loadedImage = nil }
            return
        }

        if let cached = RemoteImageCache.shared.image(for: urlString) {
            await MainActor.run { loadedImage = cached }
            return
        }

        if let cached = URLCache.shared.cachedResponse(for: URLRequest(url: url)),
           let image = UIImage.downsampled(from: cached.data, maxPixelSize: 1100) {
            RemoteImageCache.shared.insert(image, for: urlString)
            await MainActor.run { loadedImage = image }
            return
        }

        await MainActor.run { isLoading = true }

        do {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Cache the response on background thread
            URLCache.shared.storeCachedResponse(CachedURLResponse(response: response, data: data), for: request)
            
            // Perform image downsampling on background thread (it's expensive)
            let image = UIImage.downsampled(from: data, maxPixelSize: 1100)
            
            // Update UI state on main thread
            await MainActor.run {
                if let image {
                    RemoteImageCache.shared.insert(image, for: urlString)
                }
                self.loadedImage = image
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.loadedImage = nil
                self.isLoading = false
            }
        }
    }
}

private final class RemoteImageCache {
    static let shared = RemoteImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 180
        cache.totalCostLimit = 80 * 1024 * 1024
    }

    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func insert(_ image: UIImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}

private extension UIImage {
    static func downsampled(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return nil }

        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else { return nil }
        return UIImage(cgImage: image)
    }
}
