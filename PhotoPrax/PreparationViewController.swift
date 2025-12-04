//  Prax-11272
//
//  PreparationViewController.swift
//  PhotoPrax
//
//  Created by Elmer Cat on 11/26/25.
//

import Cocoa
import Combine
internal import Photos


class PreparationViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSFetchedResultsControllerDelegate {
    
    // UI elements (assume these are connected via Interface Builder)
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!

    @IBOutlet weak var photosTableView: NSTableView!
    @IBOutlet weak var albumsTableView: NSTableView!
    @IBOutlet weak var foldersTableView: NSTableView!

    @IBAction func start(_ sender: Any) {
        print("Start")
    }
    @IBAction func resetCoreData(_ sender: Any) {
        dbPrepController.resetCoreData()
  //      reloadData()
    }

    @IBAction func fetchPhotos(_ sender: Any) {
        dbPrepController.importAllPhotos()
    }
    @IBAction func fetchAlbums(_ sender: Any) {
        dbPrepController.importAllAlbums()
    }
    @IBAction func fetchFolders(_ sender: Any) {
        dbPrepController.importAllFolders()
    }

    @objc dynamic var managedObjectContext: NSManagedObjectContext = PersistenceController.shared.context
    @objc dynamic var authorized : Bool = false
    @objc dynamic var busy : Bool = false
    @objc dynamic var progressMode : String = "Prax"
    
    var fetchedPhotosController: NSFetchedResultsController<Photo>!
    var fetchedAlbumsController: NSFetchedResultsController<Album>!
    var fetchedFoldersController: NSFetchedResultsController<Folder>!
    
    var tableDataSource: TableDataSource!
    
    // ... (other properties)
    
       

    func reloadData() {
        do {
            try fetchedPhotosController.performFetch()
            print("Reloaded Photos  \(fetchedPhotosController.fetchedObjects?.count ?? 0)")
            photosTableView.reloadData()
        } catch {
            print("Fetch Photos failed: \(error)")
        }
        do {
            try fetchedAlbumsController.performFetch()
            print("Reloaded Collections  \(fetchedAlbumsController.fetchedObjects?.count ?? 0)")
            albumsTableView.reloadData()
        } catch {
            print("Fetch Collections failed: \(error)")
        }
        do {
            try fetchedFoldersController.performFetch()
            print("Reloaded Lists  \(fetchedFoldersController.fetchedObjects?.count ?? 0)")
            foldersTableView.reloadData()
        } catch {
            print("Fetch Lists failed: \(error)")
        }

    }
    

    // The controller that handles database preparation and progress
    let dbPrepController = DatabasePreparationController()
    var cancellables = Set<AnyCancellable>()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dbPrepController.$preparationStep
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
                 //   self?.reloadData()
                    self?.progressMode = "Data Reloaded"
                    self?.busy = false
                    
                default:
                    self?.progressMode = "Erika"
                }
            }
            .store(in: &cancellables)
        
        if dbPrepController.preparationStep == .waitingForAuthorization {
            dbPrepController.requestAuthorization()
        }
    }
    
    func authorizationGranted() {

        tableDataSource = TableDataSource()
        
//        setupFetchedResultsController()
        photosTableView.dataSource = tableDataSource
        photosTableView.delegate = tableDataSource
        albumsTableView.dataSource = tableDataSource
        albumsTableView.delegate = tableDataSource
        foldersTableView.dataSource = tableDataSource
        foldersTableView.delegate = tableDataSource

        // Bind status message to label
        dbPrepController.$statusMessage
            .receive(on: RunLoop.main)
            .sink { [weak self] message in
                self?.statusLabel.stringValue = message
            }
            .store(in: &cancellables)
        
        // Bind progress to progress bar
        dbPrepController.$progress
            .receive(on: RunLoop.main)
            .sink { [weak self] progress in
                self?.progressIndicator.doubleValue = progress * 100
            }
            .store(in: &cancellables)
        
        // Optionally, respond to step changes, errors, etc.
        
       
        let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
        let results = try? managedObjectContext.fetch(fetchRequest)
        print("Debug: There are \(results?.count ?? 0) Photo objects after UI has loaded.")

    }
    
 
}

