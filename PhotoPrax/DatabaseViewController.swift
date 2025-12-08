//  Prax-11272
//
//  DatabaseViewController.swift
//  PhotoPrax
//
//  Created by Elmer Cat on 11/26/25.
//

import Cocoa
import Combine
@preconcurrency import Photos


class DatabaseViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSFetchedResultsControllerDelegate {
    
    // UI elements (assume these are connected via Interface Builder)
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var photosLoaded: NSTextField!
    
    @IBOutlet weak var progressIndicatorA: NSProgressIndicator!
    @IBOutlet weak var progressIndicatorB: NSProgressIndicator!

    @IBOutlet weak var photosTableView: NSTableView!
    @IBOutlet weak var albumsTableView: NSTableView!
    @IBOutlet weak var foldersTableView: NSTableView!

    @IBAction func start(_ sender: Any) {
        print("Start")
        let token = PHPhotoLibrary.shared().currentChangeToken
        let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
        UserDefaults.standard.set(data, forKey: "PersistentChangeToken")
    }
    
    @IBAction func resetCoreData(_ sender: Any) {
        dbController.resetCoreData()
       reloadTableData()
    }

    @IBAction func fetchPhotos(_ sender: Any) {
        dbController.importAllPhotos()
    }
    @IBAction func fetchAlbums(_ sender: Any) {
        dbController.importAllAlbums()
    }
    @IBAction func fetchFolders(_ sender: Any) {
        dbController.importAllFolders()
    }

    @objc dynamic var managedObjectContext: NSManagedObjectContext = PersistenceController.shared.context
    @objc dynamic var authorized : Bool = false
    @objc dynamic var busy : Bool = false
    @objc dynamic var progressMode : String = "Prax"
    
    
    var tableDataSource: TableDataSource!
    let dbController = DatabaseController()
    var cancellables = Set<AnyCancellable>()
    

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableDataSource = TableDataSource(viewController: self)
        
        
/*        if let data = UserDefaults.standard.data(forKey: "PersistentChangeToken"),
           let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: PHPersistentChangeToken.self, from: data) {
         
            print("Last Token: ", token)
            
            let changes: PHPersistentChangeFetchResult = try! PHPhotoLibrary.shared().fetchPersistentChanges(since: token)
            print("Changes: ", changes.count(where: {$0 != nil}))
            
            for change in changes {
                print("Change: ", change)
                if let changeDetails = try? change.changeDetails(for: .asset) {
                    if changeDetails.insertedLocalIdentifiers.count > 0 {
                        print("Inserted Photos: ", changeDetails.insertedLocalIdentifiers)
                    }
                    else if changeDetails.updatedLocalIdentifiers.count > 0 {
                        print("Updated Photos: ", changeDetails.updatedLocalIdentifiers)
                    }
                    else if changeDetails.deletedLocalIdentifiers.count > 0 {
                        print("Deleted Photos: ", changeDetails.deletedLocalIdentifiers)
                    }
                }
                if let changeDetails = try? change.changeDetails(for: .assetCollection) {
                    if changeDetails.insertedLocalIdentifiers.count > 0 {
                        print("Inserted Albums: ", changeDetails.insertedLocalIdentifiers)
                    }
                    else if changeDetails.updatedLocalIdentifiers.count > 0 {
                        print("Updated Albums: ", changeDetails.updatedLocalIdentifiers)
                    }
                    else if changeDetails.deletedLocalIdentifiers.count > 0 {
                        print("Deleted Albums: ", changeDetails.deletedLocalIdentifiers)
                        print("Albums Changed: ",changeDetails.objectType.rawValue)
                        print("inserted: ", changeDetails.insertedLocalIdentifiers)
                        print("updated: ", changeDetails.updatedLocalIdentifiers)
                        print("deleted: ", changeDetails.deletedLocalIdentifiers)
                    }
                }
                if let changeDetails = try? change.changeDetails(for: .collectionList) {
                        if changeDetails.insertedLocalIdentifiers.count > 0 {
                            print("Inserted Folders: ", changeDetails.insertedLocalIdentifiers)
                        }
                        else if changeDetails.updatedLocalIdentifiers.count > 0 {
                            print("Updated Folders: ", changeDetails.updatedLocalIdentifiers)
                        }
                        else if changeDetails.deletedLocalIdentifiers.count > 0 {
                            print("Deleted Folders: ", changeDetails.deletedLocalIdentifiers)
                        }
                    }
                }
                }
        else {
            print("No Last Token")
        }
        
        let currentToken = PHPhotoLibrary.shared().currentChangeToken
        
        print("Current Token: ", currentToken)
  */
        
        dbController.$preparationStep
            .receive(on: RunLoop.main)
            .sink { [weak self] message in
                
                switch(message) {
                case .waitingForAuthorization:
                    self?.progressMode = "Waiting for Authorization"
                    
                case .authorizationGranted:
                    self?.authorized = true
                    self?.progressMode = "Authorized"
                    self?.authorizationGranted()
                    
                case .authorizationDenied:
                    self?.progressMode = "Authorization Denied in System Settings"
                    let alert = NSAlert()
                    alert.messageText = "Please allow PhotoPrax to access your Photos library"
                    alert.informativeText = "Go to: \n\nSystem Settings\n— Privacy & Security\n—— Photos\n\nTurn on the switch for PhotoPrax\n\nAfter allowing access, quit and restart PhotoPrax again."
                    alert.alertStyle = .critical // or .informational, .critical
                    alert.addButton(withTitle: "Quit PhotoPrax")
                    alert.runModal()
                    NSApplication.shared.terminate(nil)
                    
                case .buildingDatabase:
                    self?.progressMode = "Building Database"
                    self?.busy = true
                    
                case .completed:
                  //  self?.reloadData()
                    self?.progressMode = "Data Reloaded"
                    self?.busy = false
                    
                    
                default:
                    self?.progressMode = "Erika"
                }
            }
            .store(in: &cancellables)
        
        if dbController.preparationStep == .waitingForAuthorization {
            dbController.requestAuthorization()
        }
    }
    
    func authorizationGranted() {

        photosTableView.dataSource = tableDataSource
        photosTableView.delegate = tableDataSource
        albumsTableView.dataSource = tableDataSource
        albumsTableView.delegate = tableDataSource
        foldersTableView.dataSource = tableDataSource
        foldersTableView.delegate = tableDataSource

        // Bind status message to label
        dbController.$statusMessage
            .receive(on: RunLoop.main)
            .sink { [weak self] message in
                self?.statusLabel.stringValue = message
            }
            .store(in: &cancellables)

        dbController.$photosLoaded
            .receive(on: RunLoop.main)
            .sink { [weak self] message in
                self?.photosLoaded.stringValue = message.formatted()
            }
            .store(in: &cancellables)

        
        // Bind progress to progress bar
        dbController.$progressA
            .receive(on: RunLoop.main)
            .sink { [weak self] progressA in
                self?.progressIndicatorA.doubleValue = progressA * 100
            }
            .store(in: &cancellables)
        
        dbController.$progressB
            .receive(on: RunLoop.main)
            .sink { [weak self] progressB in
                self?.progressIndicatorB.doubleValue = progressB * 100
            }
            .store(in: &cancellables)
        
        // Optionally, respond to step changes, errors, etc.
        
       
        let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
        let results = try? managedObjectContext.fetch(fetchRequest)
        print("Debug: There are \(results?.count ?? 0) Photo objects after UI has loaded.")

    }
    
    func reloadTableData() {
        
        
        do {
            try tableDataSource.fetchedPhotosController.performFetch()
            print("Reloaded Photos  \(tableDataSource.fetchedPhotosController.fetchedObjects?.count ?? 0)")
            photosTableView.reloadData()
        } catch {
            print("Fetch Photos failed: \(error)")
        }
        do {
            try tableDataSource.fetchedAlbumsController.performFetch()
            print("Reloaded Albums  \(tableDataSource.fetchedAlbumsController.fetchedObjects?.count ?? 0)")
            albumsTableView.reloadData()
        } catch {
            print("Fetch Albums failed: \(error)")
        }
        do {
            try tableDataSource.fetchedFoldersController.performFetch()
            print("Reloaded Folders  \(tableDataSource.fetchedFoldersController.fetchedObjects?.count ?? 0)")
            foldersTableView.reloadData()
        } catch {
            print("Fetch Folders failed: \(error)")
        }

        
        
    }
    

 
}

