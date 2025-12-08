//  Prax-11272
//
//
//  DatabaseController.swift
//  PhotoPrax
//
//  Handles Photos authorization and database preparation, publishing progress for UI updates.

import Foundation
import CoreData
import Combine
@preconcurrency  import Photos

class DatabaseController: ObservableObject {
    
    enum ItemType: String {
        case asset
        case album
        case smartAlbum
        case userFolder
        case smartFolder
    }
    
    enum PreparationStep: String {
        case waitingForAuthorization
        case authorizationGranted
        case authorizationDenied
        case buildingDatabase
        case completed
        case failed
    }
    
    @Published var preparationStep: PreparationStep = .waitingForAuthorization
    @Published var totalPhotos: Int = 0
    @Published var photosLoaded: Date = Date.distantPast
    @Published var progressA: Double = 0.0 // 0.0 to 1.0
    @Published var progressMaxA: Double = 0.0 // 0.0 to 1.0
    @Published var progressB: Double = 0.0 // 0.0 to 1.0
    @Published var progressMaxB: Double = 0.0 // 0.0 to 1.0
    @Published var statusMessage: String = "Waiting to begin..."
    @Published var error: Error?
    
    func authorizationStatus() -> PHAuthorizationStatus {
        return PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    /// Requests photo library authorization. Note: This does NOT return the new status immediately because the request is asynchronous.
    func requestAuthorization() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if status == .authorized {
                    self.preparationStep = .authorizationGranted
                    self.statusMessage = "Authorization granted."
                }
                else {
                    self.preparationStep = .authorizationDenied
                    self.statusMessage = "Authorization denied."
                }
            }
        }
    }
    
    
    func resetCoreData() {
        guard let storeURL = PersistenceController.shared.container.persistentStoreCoordinator.persistentStores.first?.url else { return }
        
        print("Core Data store location: \(storeURL.path)")
        do {
            try PersistenceController.shared.container.persistentStoreCoordinator.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType, options: nil)
            try PersistenceController.shared.container.persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)
            // Optionally, reset the managed object context
            PersistenceController.shared.context.reset()
            print("Core Data Reset")
        } catch {
            print("Error resetting Core Data: \(error)")
        }
        
    }
    
    
    
    func addDataForFolder(_ phItem: PHCollectionList, context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "identifier == %@", phItem.localIdentifier)
        
        var folder: Folder!
        if let results = try? context.fetch(fetchRequest) {
            if results.count > 0 {
                folder = results.first!
            }
            else {
                folder = Folder(context: context)
                folder.identifier = phItem.localIdentifier
            }
        }
        
        folder.title = phItem.localizedTitle
        folder.type = Int64(Int16(phItem.collectionListType.rawValue))
        folder.subType = Int64(Int16(phItem.collectionListSubtype.rawValue))
        folder.startDate = phItem.startDate
        folder.endDate = phItem.endDate
        let albums = PHCollection.fetchCollections(in: phItem, options: PHFetchOptions())
        folder.count = Int64(albums.count)
        
        print("Contains \(albums.count) Albums.")
        albums.enumerateObjects { album, index, _ in
            print(album.localIdentifier)
            let fetchRequest: NSFetchRequest<Album> = Album.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "identifier == %@", album.localIdentifier)
            do {
                let results = try context.fetch(fetchRequest)
                if results.count > 0 {
                    let album = results[0]
                    print(album.description)
                    album.setValue(folder, forKey: "folder")
                }
                else {
                    print("Album not in Database")
                }
                
            } catch {
                print("Fetch failed: \(error)")
            }
        }
    }
    
    func addDataForAlbum(_ phItem: PHAssetCollection, context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<Album> = Album.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "identifier == %@", phItem.localIdentifier)
        
        var album: Album!
        if let results = try? context.fetch(fetchRequest) {
            if results.count > 0 {
                album = results.first!
            }
            else {
                album = Album(context: context)
                album.identifier = phItem.localIdentifier
            }
        }

        album.title = phItem.localizedTitle
        album.type = Int64(phItem.assetCollectionType.rawValue)
        album.subType = Int64(phItem.assetCollectionSubtype.rawValue)
        album.startDate = phItem.startDate
        album.endDate = phItem.endDate
        let photos = PHAsset.fetchAssets(in: phItem, options: PHFetchOptions())
        album.count = Int64(photos.count)

        print("Contains \(photos.count) Photos.")
        
        if phItem.assetCollectionType == .album {
            photos.enumerateObjects { photo, index, _ in
                DispatchQueue.main.async {
                    self.progressB = Double(index + 1) / Double(photos.count)
                    self.statusMessage = "Importing Photo: \(index + 1) of \(photos.count)."
                }
                print(photo.localIdentifier)
                let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "identifier == %@", photo.localIdentifier)
                do {
                    let results = try context.fetch(fetchRequest)
                    if results.count > 0 {
                        let photo = results[0]
                        print(photo.description)
                        photo.addToAlbums(album)
                    }
                    else {
                        print("Photo not in Database")
                    }
                } catch {
                    print("Fetch failed: \(error)")
                }
            }
        }
    }
    
    
    func importAllFolders() {
        self.preparationStep = .buildingDatabase
        
        let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
        backgroundContext.perform {
            let fetchOptions = PHFetchOptions()
            
            let folderLists = PHCollectionList.fetchCollectionLists(with: .folder, subtype: .any, options: fetchOptions)
            print("Fetched \(folderLists.count) Folder Lists.")
            
            folderLists.enumerateObjects { phItem, index, _ in
                
                
                self.addDataForFolder(phItem, context: backgroundContext)
                
                let albums = PHCollection.fetchCollections(in: phItem, options: fetchOptions)
                
                print(phItem.localizedTitle ?? "No Title", " Type: ", phItem.collectionListType.rawValue,phItem.collectionListSubtype.rawValue, "  Album? ", phItem.canContainAssets, "  Folder?", phItem.canContainCollections, "  Contains \(albums.count) Albums.")
                
                albums.enumerateObjects { phItem, index, _ in
                    print("   Album: ", phItem.localizedTitle ?? "No Title")
                }
                
                
            }
            
            let smartFolderLists = PHCollectionList.fetchCollectionLists(with: .smartFolder, subtype: .any, options: fetchOptions)
            print("Fetched \(smartFolderLists.count) Smart Folder Lists.")
            smartFolderLists.enumerateObjects { phItem, index, _ in
                self.addDataForFolder(phItem, context: backgroundContext)
                let albums = PHCollection.fetchCollections(in: phItem, options: fetchOptions)
                print(phItem.localizedTitle ?? "No Title", " Type: ", phItem.collectionListType.rawValue,phItem.collectionListSubtype.rawValue, "  Album? ", phItem.canContainAssets, "  Folder?", phItem.canContainCollections, "  Contains \(albums.count) Albums.")
                albums.enumerateObjects { phItem, index, _ in
                    print("   Album: ", phItem.localizedTitle ?? "No Title")
                }
            }
            
     /*       let topFolderLists = PHCollection.fetchTopLevelUserCollections(with: fetchOptions)
            print("Fetched \(topFolderLists.count) Top Folder Lists.")
            topFolderLists.enumerateObjects { phItem, index, _ in
                print("Top Folder List ", phItem.localizedTitle ?? "No Title")
                if let folder = phItem as? PHCollectionList {
                    self.addDataForFolder(folder, context: backgroundContext)
                    let albums = PHCollection.fetchCollections(in: folder, options: fetchOptions)
                    print(folder.localizedTitle ?? "No Title", " Type: ", folder.collectionListType.rawValue, folder.collectionListSubtype.rawValue, "  Album? ", folder.canContainAssets, "  Folder?", folder.canContainCollections, "  Contains \(albums.count) Albums.")
                    albums.enumerateObjects { album, index, _ in
                        print("   Album: ", album.localizedTitle ?? "No Title")
                    }
                }
            }
       */
            
            do {
                try backgroundContext.save()
                print("Saved Folders in background.")
            } catch {
                print("Failed to save (background): \(error)")
            }
            
            // Optional: Notify main context of changes
            DispatchQueue.main.async {
                self.progressA = 0
                self.progressB = 0
                self.preparationStep = .completed
                self.statusMessage = "Folder import complete."
            }
        }
    }
    
    func importAllAlbums() {
        self.preparationStep = .buildingDatabase
        
        let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
        backgroundContext.perform {
            let fetchOptions = PHFetchOptions()
            
            let normalAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
            let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: fetchOptions)
            
            let allAlbums = (0..<normalAlbums.count).map { normalAlbums.object(at: $0) }
            + (0..<smartAlbums.count).map { smartAlbums.object(at: $0) }

            DispatchQueue.main.async {
                self.statusMessage = "Fetched \(allAlbums.count) Albums."
                self.progressA  = 0.0
                self.progressB = 0.0
            }
            print("Fetched \(allAlbums.count) Albums.")
            
            normalAlbums.enumerateObjects { album, index, _ in
                print(album.description)
                DispatchQueue.main.async {
                    self.progressA = Double(index + 1) / Double(allAlbums.count)
                    self.progressB = 0.0
                    self.statusMessage = "Importing Album \(index + 1) of \(allAlbums.count)."
                }
                self.addDataForAlbum(album, context: backgroundContext)
            }
            smartAlbums.enumerateObjects { album, index, _ in
                print(album.description)
                DispatchQueue.main.async {
                    self.progressA = Double(normalAlbums.count + index + 1) / Double(allAlbums.count)
                    self.progressB = 0.0
                    self.statusMessage = "Importing Album \(normalAlbums.count + index + 1) of \(allAlbums.count)."
                }
                self.addDataForAlbum(album, context: backgroundContext)
            }
            
            do {
                try backgroundContext.save()
            } catch {
                print("Failed to save (background): \(error)")
            }

            
/*
          // let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: fetchOptions)
            
            
            DispatchQueue.main.async {
                
                self.statusMessage = "Fetched \(smartAlbums.count) Smart Albums."
                self.progress = 0.0            }
            
            print("Fetched \(smartAlbums.count) Smart Albums..")
            
            smartAlbums.enumerateObjects { phItem, index, _ in
                
                print(phItem.description)

                
                self.addDataForAlbum(phItem, context: backgroundContext)
                
                do {
                    try backgroundContext.save()
                } catch {
                    print("Failed to save (background): \(error)")
                }
            }
            
 */
            
            DispatchQueue.main.async {
                self.progressA = 0
                self.progressB = 0
                self.preparationStep = .completed
                self.statusMessage = "Album import complete."
            }
            
            print("Saved Albums in background.")
            
        }
    }
    
    
    func importAllPhotos() {
        // 1. Create a private background context
        
        if self.photosLoaded == Date.distantPast {
            print("Loding first time")
        }
        else
        {
            print("Previously loaded ", self.photosLoaded.formatted())
        }
        
        self.preparationStep = .buildingDatabase
        
        let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
        
        // 2. Run import on a background queue
        backgroundContext.perform {
            let fetchOptions = PHFetchOptions()
            let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
            
            self.totalPhotos = fetchResult.count
            
            DispatchQueue.main.async {
                
                self.statusMessage = "Fetched \(self.totalPhotos) Photos."
                self.progressA = 0.0
                self.progressB = 0.0
            }
            
            print("Fetched \(self.totalPhotos) assets.")
            
            fetchResult.enumerateObjects { phAsset, index, _ in
                let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "identifier == %@", phAsset.localIdentifier)
                
                DispatchQueue.main.async {
                    self.progressA = Double(index + 1) / Double(self.totalPhotos)
                    self.statusMessage = "Importing photo \(index + 1) of \(self.totalPhotos)."
                }
                
                var photo: Photo!
                if let results = try? backgroundContext.fetch(fetchRequest) {
                    if results.count > 0 {
                        photo = results.first!
                    }
                    else {
                        photo = Photo(context: backgroundContext)
                        photo.identifier = phAsset.localIdentifier
                    }
                }

                photo.count = Int64(truncating: (photo.albums?.count)! as NSNumber)
                photo.type = Int64(phAsset.mediaType.rawValue)
                photo.creationDate = phAsset.creationDate
                photo.modificationDate = phAsset.modificationDate
                
            }
            
            do {
                try backgroundContext.save()
            } catch {
                print("Failed to save (background): \(error)")
            }
            
            // Optional: Notify main context of changes
            DispatchQueue.main.async {
                self.progressA = 0
                self.progressB = 0
                self.preparationStep = .completed
                self.statusMessage = "Photo import complete."
                self.photosLoaded = Date()
            }
            
            print("Saved \(self.totalPhotos) photos in background.")
        }
    }

}

