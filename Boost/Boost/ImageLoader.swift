//
//  ImageLoader.swift
//  Boost
//
//  Created for image downloading and caching
//

import SwiftUI
import Combine

/**
 * ImageLoader
 * A singleton class responsible for downloading, caching, and managing remote images.
 * Features:
 * - In-memory caching of downloaded images
 * - Asynchronous image downloading using Combine publishers
 * - Error handling for failed downloads or invalid URLs
 */
class ImageLoader: ObservableObject {
    static let shared = ImageLoader()
    
    // In-memory cache
    private var cache = NSCache<NSString, UIImage>()
    
    @Published var image: UIImage?
    @Published var isLoading = false
    @Published var error: Error?
    
    private var cancellables = Set<AnyCancellable>()
    
    /**
     * Get a cached image if it exists
     * @param urlString The URL string used as the cache key
     * @return The cached UIImage if it exists, nil otherwise
     */
    func getCachedImage(for urlString: String) -> UIImage? {
        return cache.object(forKey: NSString(string: urlString))
    }
    
    /**
     * Store a cancellable in the shared set
     * @param cancellable The AnyCancellable to store
     */
    func store(cancellable: AnyCancellable) {
        cancellables.insert(cancellable)
    }
    
    /**
     * Load an image from the specified URL string
     * - Checks the in-memory cache first
     * - Downloads the image if not in cache
     * - Stores the downloaded image in cache for future use
     *
     * @param urlString The URL of the image to download
     * @return A publisher that will emit the image or an error
     */
    func loadImage(from urlString: String) -> AnyPublisher<UIImage?, Error> {
        // Clean up URL string
        let trimmedUrlString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUrlString.isEmpty else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        // Check cache first
        if let cachedImage = cache.object(forKey: NSString(string: trimmedUrlString)) {
            print("✅ Using cached image for \(trimmedUrlString)")
            return Just(cachedImage)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // Create URL
        guard let url = URL(string: trimmedUrlString) else {
            print("❌ Invalid URL: \(trimmedUrlString)")
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        print("🔄 Downloading image from \(trimmedUrlString)")
        
        // Download image
        return URLSession.shared.dataTaskPublisher(for: url)
            .map { data, response -> UIImage? in
                guard let image = UIImage(data: data) else {
                    print("❌ Failed to convert data to image for \(urlString)")
                    return nil
                }
                
                // Save to cache
                self.cache.setObject(image, forKey: NSString(string: trimmedUrlString))
                print("✅ Image downloaded and cached for \(trimmedUrlString)")
                return image
            }
            .mapError { error -> Error in
                print("❌ Error downloading image: \(error.localizedDescription)")
                return error
            }
            .eraseToAnyPublisher()
    }
    
    /**
     * Clear the in-memory image cache
     */
    func clearCache() {
        cache.removeAllObjects()
        print("🧹 Image cache cleared")
    }
}

/**
 * RemoteImage
 * A SwiftUI view that handles displaying remote images with loading states
 * - Shows a loading indicator while the image downloads
 * - Displays the image when downloaded
 * - Shows a fallback gradient if download fails
 *
 * Usage: RemoteImage(url: "https://example.com/image.jpg")
 */
struct RemoteImage: View {
    private enum LoadState {
        case loading, success, failure
    }
    
    private let url: String
    @State private var loadState = LoadState.loading
    @State private var image: UIImage?
    
    init(url: String) {
        self.url = url
    }
    
    var body: some View {
        selectImage()
            .onAppear(perform: loadImage)
    }
    
    private func loadImage() {
        if let cachedImage = ImageLoader.shared.getCachedImage(for: url) {
            self.image = cachedImage
            self.loadState = .success
            return
        }
        
        let cancellable = ImageLoader.shared.loadImage(from: url)
            .sink { completion in
                if case .failure = completion {
                    self.loadState = .failure
                }
            } receiveValue: { image in
                self.image = image
                self.loadState = image != nil ? .success : .failure
            }
        
        ImageLoader.shared.store(cancellable: cancellable)
    }
    
    private func selectImage() -> some View {
        switch loadState {
        case .loading:
            return AnyView(ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity))
        case .success:
            return AnyView(
                Image(uiImage: image!)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            )
        case .failure:
            return AnyView(
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.8), Color.gray.opacity(0.5)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
} 