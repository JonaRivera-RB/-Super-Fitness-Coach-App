//
//  ExerciseImageLoader.swift
//  Super Fitness Coach App
//

import SwiftUI
import ImageIO
import os

/// Downloads and caches exercise GIF data from ExerciseDB API.
/// The API requires authentication headers, so standard AsyncImage cannot be used.
@Observable
final class ExerciseImageLoader {

    private let apiKey: String
    private let apiHost: String
    private let session: URLSession
    private let logger = Logger(subsystem: "com.superfitness.coach", category: "ExerciseImageLoader")

    /// In-memory data cache keyed by exercise ID (raw GIF/image bytes).
    private var cache: [String: Data] = [:]

    /// Track in-flight downloads to avoid duplicate requests.
    private var inFlight: Set<String> = []

    init(
        apiKey: String = "",
        apiHost: String = "exercisedb.p.rapidapi.com",
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.apiHost = apiHost
        self.session = session
    }

    /// Load exercise image data by exercise ID. Returns cached data if available.
    func loadImageData(exerciseId: String) async -> Data? {
        if let cached = cache[exerciseId] {
            return cached
        }

        guard !inFlight.contains(exerciseId) else { return nil }
        guard !apiKey.isEmpty else { return nil }

        inFlight.insert(exerciseId)
        defer { inFlight.remove(exerciseId) }

        // ExerciseDB image service supports multiple resolutions; some tiers only allow low res.
        // Also, docs support passing key as query parameter; we do both headers + query for compatibility.
        let resolutions = [1080, 720, 360, 180]

        for res in resolutions {
            guard var comps = URLComponents(string: "https://\(apiHost)/image") else { continue }
            comps.queryItems = [
                URLQueryItem(name: "resolution", value: "\(res)"),
                URLQueryItem(name: "exerciseId", value: exerciseId),
                URLQueryItem(name: "rapidapi-key", value: apiKey),
            ]
            guard let url = comps.url else { continue }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
            request.setValue(apiHost, forHTTPHeaderField: "X-RapidAPI-Host")
            request.timeoutInterval = 30

            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else { continue }
                guard httpResponse.statusCode == 200, !data.isEmpty else {
                    logger.warning("Image fetch failed for \(exerciseId) at \(res)p: HTTP \(httpResponse.statusCode)")
                    continue
                }

                logger.info("Image fetch OK for \(exerciseId) at \(res)p: \(data.count) bytes, content-type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")
                cache[exerciseId] = data
                return data
            } catch {
                logger.error("Image download error for \(exerciseId) at \(res)p: \(error.localizedDescription)")
                continue
            }
        }

        return nil
    }

    func clearCache() {
        cache.removeAll()
    }
}

// MARK: - Animated GIF View

/// Displays animated GIF data using UIKit's native GIF support.
struct AnimatedGIFView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        loadGIF(into: imageView)
        return imageView
    }

    func updateUIView(_ imageView: UIImageView, context: Context) {
        loadGIF(into: imageView)
    }

    private func loadGIF(into imageView: UIImageView) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            // Fallback: try as static image
            imageView.image = UIImage(data: data)
            return
        }

        let frameCount = CGImageSourceGetCount(source)

        if frameCount <= 1 {
            // Static image
            imageView.image = UIImage(data: data)
            return
        }

        // Extract all frames and durations for animated GIF
        var frames: [UIImage] = []
        var totalDuration: Double = 0

        for i in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            frames.append(UIImage(cgImage: cgImage))

            // Get frame duration
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
               let gifProps = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                let delay = gifProps[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
                    ?? gifProps[kCGImagePropertyGIFDelayTime as String] as? Double
                    ?? 0.1
                // Enforce minimum 0.06s per frame to prevent overly fast playback
                totalDuration += max(delay, 0.06)
            } else {
                totalDuration += 0.1
            }
        }

        imageView.animationImages = frames
        imageView.animationDuration = totalDuration
        imageView.animationRepeatCount = 0 // loop forever
        imageView.startAnimating()
    }
}
