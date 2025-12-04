//  Prax-11272
//
//
//  DatabasePreparationController.swift
//  PhotoPrax
//
//  Handles Photos authorization and database preparation, publishing progress for UI updates.

import Foundation
import CoreData
import Combine
internal import Photos

class DatabasePreparationController: ObservableObject {
    
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
    @Published var progress: Double = 0.0 // 0.0 to 1.0
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
                    //   self.buildDatabase()
                } else {
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
    
    
    func importFoldersForLists() {
        
    }
    
    func addDataForList(_ phItem: PHCollectionList, context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "identifier == %@", phItem.localIdentifier)
        
        if let existing = try? context.fetch(fetchRequest), !existing.isEmpty {
            return
        }
        
        let list = Folder(context: context)
        list.identifier = phItem.localIdentifier
        list.title = phItem.localizedTitle
        list.type = Int64(Int16(phItem.collectionListType.rawValue))
        list.subType = Int64(Int16(phItem.collectionListSubtype.rawValue))
        list.startDate = phItem.startDate
        list.endDate = phItem.endDate
        
    }
    
    func addDataForAlbum(_ phItem: PHAssetCollection, context: NSManagedObjectContext) {
        
        print(phItem.description)

        
        let fetchRequest: NSFetchRequest<Album> = Album.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "identifier == %@", phItem.localIdentifier)
        
        
        if let existing = try? context.fetch(fetchRequest), !existing.isEmpty {
            return
        }
        
        let album = Album(context: context)
        album.identifier = phItem.localIdentifier
        album.title = phItem.localizedTitle
        album.type = Int64(phItem.assetCollectionType.rawValue)
        album.subType = Int64(phItem.assetCollectionSubtype.rawValue)
        album.startDate = phItem.startDate
        album.endDate = phItem.endDate
        album.count = Int64(phItem.estimatedAssetCount)
        
    }
    
    
    func importAllFolders() {
        // 1. Create a private background context
        
        self.preparationStep = .buildingDatabase
        
        let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
        
        // 2. Run import on a background queue
        backgroundContext.perform {
            let fetchOptions = PHFetchOptions()
            
            let folderLists = PHCollectionList.fetchCollectionLists(with: .folder, subtype: .any, options: fetchOptions)
            print("Fetched \(folderLists.count) Folder Lists.")
            
            folderLists.enumerateObjects { phItem, index, _ in
                
                print(phItem.description)
                print(phItem.canContainAssets)
                print(phItem.canContainCollections)
                
                self.addDataForList(phItem, context: backgroundContext)
                
                let albums = PHCollection.fetchCollections(in: phItem, options: fetchOptions)
                
                print("Contains \(albums.count) Albums.")
                
                albums.enumerateObjects { album, index, _ in
                    
                    print(album.description)
                    
                }
                
            }
            
            let smartFolderLists = PHCollectionList.fetchCollectionLists(with: .smartFolder, subtype: .any, options: fetchOptions)
            print("Fetched \(smartFolderLists.count) Smart Folder Lists.")
            
            smartFolderLists.enumerateObjects { phItem, index, _ in
                
                print(phItem.description)
                print(phItem.canContainAssets)
                print(phItem.canContainCollections)
                
                self.addDataForList(phItem, context: backgroundContext)
                
                
                let albums = PHCollection.fetchCollections(in: phItem, options: fetchOptions)
                
                print("Contains \(albums.count) Albums.")
                
                albums.enumerateObjects { album, index, _ in
                    
                    print(album.description)
                    
                }
                
            }
            
            let topFolderLists = PHCollection.fetchTopLevelUserCollections(with: fetchOptions)
            print("Fetched \(topFolderLists.count) Top Folder Lists.")
            
            
            
            topFolderLists.enumerateObjects { phItem, index, _ in
                
                print(phItem.description)
                print(phItem.canContainAssets)
                print(phItem.canContainCollections)
                
                if phItem is PHCollectionList {
                    self.addDataForList(phItem as! PHCollectionList, context: backgroundContext)
                }
                
            }
            
            
            do {
                try backgroundContext.save()
            } catch {
                print("Failed to save (background): \(error)")
            }
            
            // Optional: Notify main context of changes
            DispatchQueue.main.async {
                self.progress = 0
                self.preparationStep = .completed
                self.statusMessage = "Folder import complete."
            }
            
            print("Saved Folders in background.")
     }
    }
    
    func importAllAlbums() {
        // 1. Create a private background context
        
        self.preparationStep = .buildingDatabase
        
        let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
        
        // 2. Run import on a background queue
        backgroundContext.perform {
            let fetchOptions = PHFetchOptions()

            let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
            
            DispatchQueue.main.async {
                
                self.statusMessage = "Fetched \(albums.count) Albums."
                self.progress = 0.0            }
            
            print("Fetched \(albums.count) Albums.")
            
            albums.enumerateObjects { phItem, index, _ in


                self.addDataForAlbum(phItem, context: backgroundContext)
                
                do {
                    try backgroundContext.save()
                } catch {
                    print("Failed to save (background): \(error)")
                }
            }
            
            let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: fetchOptions)
            
            
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
            

            
            DispatchQueue.main.async {
                self.progress = 0
                self.preparationStep = .completed
                self.statusMessage = "Album import complete."
            }

               print("Saved Albums in background.")
            
        }
    }
    
    
    func importAllPhotos() {
        // 1. Create a private background context
        
        self.preparationStep = .buildingDatabase
        
        let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
        
        // 2. Run import on a background queue
        backgroundContext.perform {
            let fetchOptions = PHFetchOptions()
            let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
            
            self.totalPhotos = fetchResult.count
            
            DispatchQueue.main.async {
                
                self.statusMessage = "Fetched \(self.totalPhotos) Photos."
                self.progress = 0.0            }
            
            print("Fetched \(self.totalPhotos) assets.")
            
            fetchResult.enumerateObjects { phAsset, index, _ in
                let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "identifier == %@", phAsset.localIdentifier)
                
                DispatchQueue.main.async {
                    self.progress = Double(index + 1) / Double(self.totalPhotos)
                    self.statusMessage = "Importing asset \(index + 1) of \(self.totalPhotos)."
                }
                
                
                if let existing = try? backgroundContext.fetch(fetchRequest), !existing.isEmpty {
                    return
                }
                
                let asset = Photo(context: backgroundContext)
                asset.identifier = phAsset.localIdentifier
                asset.type = Int64(Int16(phAsset.mediaType.rawValue))
                asset.creationDate = phAsset.creationDate
                asset.modificationDate = phAsset.modificationDate
                
                DispatchQueue.main.async {
                    self.progress = Double(index + 1) / Double(self.totalPhotos)
                    self.statusMessage = "Importing asset \(index + 1) of \(self.totalPhotos)."
                }
            }
            
            do {
                try backgroundContext.save()
            } catch {
                print("Failed to save (background): \(error)")
            }
            
            // Optional: Notify main context of changes
            DispatchQueue.main.async {
                self.progress = 0
                self.preparationStep = .completed
                self.statusMessage = "Photo import complete."
            }
            
            print("Saved \(self.totalPhotos) assets in background.")
        }
    }
    
    
    func buildDatabase() {
        
        self.statusMessage = "Building database..."
        
        // Example: Simulate progress. Replace with real asset fetching and DB code.
        let total = 100
        for i in 1...total {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.01) {
                self.progress = Double(i) / Double(total)
                self.statusMessage = "Processing item \(i) of \(total)..."
                if i == total {
                    self.preparationStep = .completed
                    self.statusMessage = "Database preparation complete."
                }
            }
        }
    }
}

