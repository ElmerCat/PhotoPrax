//  Prax-1207-0
//
//  PhotoLibraryViewModel.swift
//  PhotoPrax
//
//  Created by Elmer Cat on 9/28/25.
//

import SwiftUI
@preconcurrency import Photos
import Combine

@MainActor class PhotoLibraryViewModel: ObservableObject {
    @available(*, deprecated, message: "Use a per-scene @StateObject and inject into ContentView.")
    static let shared = PhotoLibraryViewModel()
    
    @Published var assets: [PHAsset] = []
    @Published var userAlbums: [PHAssetCollection] = []
    @Published var smartAlbums: [PHAssetCollection] = []
    @Published var albumCounts: [String: Int] = [:]
    @Published var allPhotosCount: Int = 0
    @Published var noAlbumsCount: Int = 0
    @Published var isLoadingAssets: Bool = false
    @Published var isLoadingAlbumCounts: Bool = false
    
    private var lastSelectionKey: String? = nil
    private var loadAssetsDebounce: DispatchWorkItem? = nil
    private var didComputeAlbumCounts: Bool = false
    
    init() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite)  { status in
            print("Authorization status: \(status.rawValue)")
            
            if status == .authorized || status == .limited {
                Task { @MainActor in
                    self.loadAlbums()
                }
            }
        }
    }
    
    func loadAllAssets() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d || mediaType == %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        
        DispatchQueue.main.async {
            self.isLoadingAssets = true
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = PHAsset.fetchAssets(with: fetchOptions)
            var fetchedAssets: [PHAsset] = []
            result.enumerateObjects { asset, _, _ in
                fetchedAssets.append(asset)
            }
            DispatchQueue.main.async {
                self.assets = fetchedAssets
                self.isLoadingAssets = false
            }
        }
    }
    
    func loadAssetsNotInAnyAlbum() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d || mediaType == %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        
        DispatchQueue.main.async {
            self.isLoadingAssets = true
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let allAssets = PHAsset.fetchAssets(with: fetchOptions)
            
            var notInAnyAlbum: [PHAsset] = []
            allAssets.enumerateObjects { asset, _, _ in
                autoreleasepool {
                    let containing = PHAssetCollection.fetchAssetCollectionsContaining(asset, with: .album, options: nil)
                    if containing.count == 0 {
                        notInAnyAlbum.append(asset)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.assets = notInAnyAlbum
                self.isLoadingAssets = false
            }
        }
    }
    
    func loadAssets(in collection: PHAssetCollection) {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d || mediaType == %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        
        DispatchQueue.main.async {
            self.isLoadingAssets = true
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = PHAsset.fetchAssets(in: collection, options: options)
            var fetchedAssets: [PHAsset] = []
            result.enumerateObjects { asset, _, _ in
                fetchedAssets.append(asset)
            }
            DispatchQueue.main.async {
                self.assets = fetchedAssets
                self.isLoadingAssets = false
            }
        }
    }
    
    @MainActor func loadAssets(for selection: Set<SidebarItem>) {
        // Compute a stable key for the selection
        let key = selection.map { $0.resetID }.sorted().joined(separator: "|")
        
        // If the selection hasn't changed and we already have content, skip reloading
        if key == self.lastSelectionKey && !self.assets.isEmpty {
            return
        }
        self.lastSelectionKey = key
        
        // Cancel any pending work and show a loading state
        self.loadAssetsDebounce?.cancel()
        self.isLoadingAssets = true
        
        // Snapshot current albums and selection to avoid races
        let albumsSnapshot = self.userAlbums + self.smartAlbums
        let selectionSnapshot = Array(selection)
        
        // Prepare fetch options
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d || mediaType == %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        
        let work = DispatchWorkItem {
            // If nothing is selected, clear and stop
            if selectionSnapshot.isEmpty {
                DispatchQueue.main.async {
                    self.assets = []
                    self.isLoadingAssets = false
                }
                return
            }
            
            // If All Photos (exclusive) is selected, load it directly
            if selectionSnapshot.contains(.allPhotos) {
                let result = PHAsset.fetchAssets(with: options)
                var fetched: [PHAsset] = []
                fetched.reserveCapacity(result.count)
                result.enumerateObjects { asset, _, _ in
                    fetched.append(asset)
                }
                DispatchQueue.main.async {
                    self.assets = fetched
                    self.isLoadingAssets = false
                }
                return
            }
            
            var assetMap: [String: PHAsset] = [:]
            
            for item in selectionSnapshot {
                switch item {
                case .allPhotos:
                    // handled above
                    break
                case .noAlbums:
                    let allAssets = PHAsset.fetchAssets(with: options)
                    allAssets.enumerateObjects { asset, _, _ in
                        autoreleasepool {
                            let containing = PHAssetCollection.fetchAssetCollectionsContaining(asset, with: .album, options: nil)
                            if containing.count == 0 {
                                assetMap[asset.localIdentifier] = asset
                            }
                        }
                    }
                case .album(let id):
                    if let album = albumsSnapshot.first(where: { $0.localIdentifier == id }) {
                        let result = PHAsset.fetchAssets(in: album, options: options)
                        result.enumerateObjects { asset, _, _ in
                            assetMap[asset.localIdentifier] = asset
                        }
                    } else {
                        // Fallback: fetch the album collection directly by its localIdentifier to avoid races
                        let fetch = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil)
                        if let album = fetch.firstObject {
                            let result = PHAsset.fetchAssets(in: album, options: options)
                            result.enumerateObjects { asset, _, _ in
                                assetMap[asset.localIdentifier] = asset
                            }
                        }
                    }
                }
            }
            
            let merged = Array(assetMap.values).sorted { a, b in
                let da = a.creationDate ?? .distantPast
                let db = b.creationDate ?? .distantPast
                return da > db
            }
            
            DispatchQueue.main.async {
                self.assets = merged
                self.isLoadingAssets = false
            }
        }
        
        self.loadAssetsDebounce = work
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.15, execute: work)
    }
    
    func loadAlbums() {
        var user: [PHAssetCollection] = []
        var smart: [PHAssetCollection] = []
        
        let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        userAlbums.enumerateObjects { collection, _, _ in
            user.append(collection)
        }
        
        let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
        smartAlbums.enumerateObjects { collection, _, _ in
            smart.append(collection)
        }
        
        // Sort by localized title when available
        user.sort { ($0.localizedTitle ?? "") < ($1.localizedTitle ?? "") }
        smart.sort { ($0.localizedTitle ?? "") < ($1.localizedTitle ?? "") }
        
        DispatchQueue.main.async {
            self.userAlbums = user
            self.smartAlbums = smart
            self.updateAlbumCounts()
            // syncSelectedAlbumIfNeeded to be called from ContentView; here we just notify
        }
    }
    
    func updateAlbumCounts(force: Bool = false) {
        // Avoid recomputing counts for every new window/tab unless explicitly forced
        if !force {
            if self.didComputeAlbumCounts || self.isLoadingAlbumCounts {
                return
            }
        } else if self.isLoadingAlbumCounts {
            // If a computation is already in progress, don't start another
            return
        }

        // Use the same predicate as the assets list (images + videos)
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d || mediaType == %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)

        DispatchQueue.main.async {
            self.isLoadingAlbumCounts = true
        }

        // Snapshot the albums to avoid races with UI updates
        let albumsSnapshot = self.userAlbums + self.smartAlbums

        DispatchQueue.global(qos: .userInitiated).async {
            // 1) Compute and publish All Photos first (fast)
            let allCount = PHAsset.fetchAssets(with: options).count
            DispatchQueue.main.async {
                self.allPhotosCount = allCount
            }

            // 2) Compute per-album counts and publish incrementally
            for album in albumsSnapshot {
                autoreleasepool {
                    let result = PHAsset.fetchAssets(in: album, options: options)
                    let count = result.count
                    DispatchQueue.main.async {
                        self.albumCounts[album.localIdentifier] = count
                    }
                }
            }

            // 3) Compute "Not In Any Album" last (most expensive). Do this after others are visible.
            var notInAnyAlbumCount = 0
            let allAssets = PHAsset.fetchAssets(with: options)
            allAssets.enumerateObjects { asset, _, _ in
                autoreleasepool {
                    let containing = PHAssetCollection.fetchAssetCollectionsContaining(asset, with: .album, options: nil)
                    if containing.count == 0 {
                        notInAnyAlbumCount += 1
                    }
                }
            }

            // 4) Publish final values and mark complete
            DispatchQueue.main.async {
                self.noAlbumsCount = notInAnyAlbumCount
                self.didComputeAlbumCounts = true
                self.isLoadingAlbumCounts = false
            }
        }
    }
    func refreshAlbumCounts() {
        updateAlbumCounts(force: true)
    }
}

