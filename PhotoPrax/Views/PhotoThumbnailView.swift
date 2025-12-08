//  Prax-1207-0
//
//  PhotoThumbnailView.swift
//  PhotoPrax
//
import SwiftUI
import Photos
import AVFoundation
import AppKit

@MainActor
struct PhotoThumbnailView: View {
    private typealias PlatformImage = NSImage

    let asset: PHAsset
    var size: CGFloat = 80

    @State private var image: PlatformImage? = nil
    @State private var requestID: PHImageRequestID? = nil
    @State private var debugInfo: String? = nil
    @MainActor private static let imageManager = PHCachingImageManager()

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Rectangle().fill(.quaternary)
                    ProgressView()
#if DEBUG
                    if let debugInfo {
                        Text(debugInfo)
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(4)
                    }
#endif
                }
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .task(id: asset.localIdentifier) { await ensureAuthorizationAndRequest() }
        .onDisappear { cancelRequest() }
        .accessibilityLabel(Text(accessibilityLabel))
    }

    private var accessibilityLabel: String {
        if let date = asset.creationDate {
            return "Photo taken on \(date.formatted(date: .long, time: .omitted))"
        } else {
            return "Photo"
        }
    }

    private func ensureAuthorizationAndRequest() async {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current == .notDetermined {
            let newStatus: PHAuthorizationStatus = await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                    continuation.resume(returning: status)
                }
            }
            if newStatus == .authorized {
                requestImage()
            } else {
                DispatchQueue.main.async { self.debugInfo = "Photos access not granted"; self.image = nil }
            }
        } else if current == .authorized {
            requestImage()
        } else {
            DispatchQueue.main.async { self.debugInfo = "Photos access not granted"; self.image = nil }
        }
    }

    private func requestImage() {
        cancelRequest()

        DispatchQueue.main.async { self.image = nil; self.debugInfo = "Requesting thumbnail…" }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.version = .current
        options.isNetworkAccessAllowed = true

        let targetSize = computeTargetPixelSize(side: size)

        // Prefetch/cache for this asset to improve reliability
        Self.imageManager.startCachingImages(for: [asset], targetSize: targetSize, contentMode: .aspectFill, options: options)

        requestID = Self.imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { result, info in

            let infoDict = info as? [String: Any] ?? [:]

            if let error = infoDict[PHImageErrorKey] as? NSError {
                DispatchQueue.main.async { self.debugInfo = error.localizedDescription }
            }

            if let cancelled = infoDict[PHImageCancelledKey] as? NSNumber, cancelled.boolValue {
                DispatchQueue.main.async { self.debugInfo = "Request cancelled" }
            }
            if let inCloud = infoDict[PHImageResultIsInCloudKey] as? NSNumber, inCloud.boolValue {
                DispatchQueue.main.async { self.debugInfo = "In iCloud, fetching…" }
            }

            if let result {
                DispatchQueue.main.async { self.image = result; self.debugInfo = nil }
                return
            }

            if asset.mediaType == .video {
                requestVideoFrameFallback()
            } else {
                requestImageDataFallback()
            }
            // Last resort: request a full-size image.
            requestFullImageFallback()
        }
    }

    // Fallback to image data if thumbnail request yields nil
    private func requestImageDataFallback() {
        let dataOptions = PHImageRequestOptions()
        dataOptions.version = .current
        dataOptions.isSynchronous = false
        dataOptions.isNetworkAccessAllowed = true

        requestID = Self.imageManager.requestImageDataAndOrientation(for: asset, options: dataOptions) { data, _, _, _ in
            guard let data else { DispatchQueue.main.async { self.debugInfo = "Data fallback returned nil" }; return }
            let img = NSImage(data: data)
            if let img {
                DispatchQueue.main.async { if self.image == nil { self.image = img; self.debugInfo = nil } }
            }
        }
    }

    // Fallback for video assets: generate a frame image
    private func requestVideoFrameFallback() {
        let videoOptions = PHVideoRequestOptions()
        videoOptions.isNetworkAccessAllowed = true

        requestID = Self.imageManager.requestAVAsset(forVideo: asset, options: videoOptions) { avAsset, _, _ in
            guard let avAsset else { return }
            let generator = AVAssetImageGenerator(asset: avAsset)
            generator.appliesPreferredTrackTransform = true
            let maxSize = computeTargetPixelSize(side: size)
            generator.maximumSize = maxSize
            let time = CMTime(seconds: 0.1, preferredTimescale: 600)

            if #available(macOS 15.0, *) {
                generator.generateCGImageAsynchronously(for: time) { cgImage, actualTime, error in
                    if let error {
                        DispatchQueue.main.async { self.debugInfo = error.localizedDescription }
                        return
                    }
                    guard let cgImage else {
                        DispatchQueue.main.async { self.debugInfo = "Video frame generation failed" }
                        return
                    }
                    let img = NSImage(cgImage: cgImage, size: .init(width: maxSize.width, height: maxSize.height))
                    DispatchQueue.main.async { if self.image == nil { self.image = img; self.debugInfo = nil } }
                }
            } else {
                if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                    let img = NSImage(cgImage: cgImage, size: .init(width: maxSize.width, height: maxSize.height))
                    DispatchQueue.main.async { if self.image == nil { self.image = img; self.debugInfo = nil } }
                } else {
                    DispatchQueue.main.async { self.debugInfo = "Video frame generation failed" }
                }
            }
        }
    }

    // Final fallback: request a full-size image if thumbnails and data fallback failed
    private func requestFullImageFallback() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none
        options.isNetworkAccessAllowed = true

        requestID = Self.imageManager.requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .default,
            options: options
        ) { result, info in
            if let result {
                DispatchQueue.main.async { if self.image == nil { self.image = result; self.debugInfo = nil } }
            } else if let info = info as? [String: Any], let error = info[PHImageErrorKey] as? NSError {
                DispatchQueue.main.async { self.debugInfo = error.localizedDescription }
            }
        }
    }

    private func cancelRequest() {
        if let id = requestID {
            Self.imageManager.cancelImageRequest(id)
            requestID = nil
        }
        Self.imageManager.stopCachingImages(for: [asset], targetSize: computeTargetPixelSize(side: size), contentMode: .aspectFill, options: nil)
    }

    private func computeTargetPixelSize(side: CGFloat) -> CGSize {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let px = side * scale
        return CGSize(width: px, height: px)
    }
}
