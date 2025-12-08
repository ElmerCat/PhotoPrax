//
//  TableDataSource.swift
//  PhotoPrax

import Cocoa

class TableDataSource: NSObject, NSTableViewDataSource, NSFetchedResultsControllerDelegate {
    
   var viewController: DatabaseViewController!
    var fetchedFoldersController: NSFetchedResultsController<Folder>!
    var fetchedAlbumsController: NSFetchedResultsController<Album>!
    var fetchedPhotosController: NSFetchedResultsController<Photo>!
    
    init(viewController: DatabaseViewController) {
        super.init()
        self.viewController = viewController
        
        let foldersFetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
        foldersFetchRequest.sortDescriptors = [NSSortDescriptor(key: "identifier", ascending: true)]
        let albumsFetchRequest: NSFetchRequest<Album> = Album.fetchRequest()
        albumsFetchRequest.sortDescriptors = [NSSortDescriptor(key: "identifier", ascending: true)]
        let photosFetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
        photosFetchRequest.sortDescriptors = [NSSortDescriptor(key: "identifier", ascending: true)]
        
        self.fetchedFoldersController = NSFetchedResultsController(
            fetchRequest: foldersFetchRequest, managedObjectContext: self.viewController.managedObjectContext, sectionNameKeyPath: nil, cacheName: nil
        )
        self.fetchedAlbumsController = NSFetchedResultsController(
            fetchRequest: albumsFetchRequest, managedObjectContext: self.viewController.managedObjectContext, sectionNameKeyPath: nil, cacheName: nil
        )
        self.fetchedPhotosController = NSFetchedResultsController(
            fetchRequest: photosFetchRequest, managedObjectContext: self.viewController.managedObjectContext, sectionNameKeyPath: nil, cacheName: nil
        )
        
        self.fetchedFoldersController.delegate = self
        self.fetchedAlbumsController.delegate = self
        self.fetchedPhotosController.delegate = self
        
        do {
            try self.fetchedFoldersController.performFetch()
            print("Folders TableDataSource Fetch performed \(self.fetchedFoldersController?.fetchedObjects?.count ?? 0)")
            //    photosTableView.reloadData()
        } catch {
            print("Fetch failed: \(error)")
        }
        do {
            try self.fetchedAlbumsController.performFetch()
            print("Albums TableDataSource Fetch performed \(self.fetchedAlbumsController?.fetchedObjects?.count ?? 0)")
            //    photosTableView.reloadData()
        } catch {
            print("Fetch failed: \(error)")
        }
        do {
            try self.fetchedPhotosController.performFetch()
            print("Photos TableDataSource Fetch performed \(self.fetchedPhotosController?.fetchedObjects?.count ?? 0)")
            //    photosTableView.reloadData()
        } catch {
            print("Fetch failed: \(error)")
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextDidSave(notification:)),
            name: .NSManagedObjectContextDidSave,
            object: nil // or nil to listen to all saves
        )
    }
    @objc func contextDidSave(notification: Notification) {
//        print("\n\n contextDidSave\n\n")
        viewController.managedObjectContext.perform {
            self.viewController.managedObjectContext.mergeChanges(fromContextDidSave: notification)
        }
    }

    
    func numberOfRows(in tableView: NSTableView) -> Int {
        switch tableView.identifier?.rawValue {
        case "photos":
            return fetchedPhotosController?.fetchedObjects?.count ?? 0
        case "albums":
            return fetchedAlbumsController?.fetchedObjects?.count ?? 0
        case "folders":
            return fetchedFoldersController?.fetchedObjects?.count ?? 0
        default:
            print("Prax NSTableViewDataSource")
            return 0
        }
     }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
//        print("\n\n controllerDidChangeContent\n\n")
        self.viewController.reloadTableData() // or use fine-grained updates
    }
}


extension TableDataSource: NSTableViewDelegate {
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        print("tableViewSelectionDidChange \n", notification.description)
        let tableView = notification.object as! NSTableView
        let selection = tableView.selectedRowIndexes
        print("selectedRowIndexes \n", selection.description)
        if selection.count > 0 {
            let selectedFolder = fetchedFoldersController?.fetchedObjects?[selection.first!]
            print("selectedFolder \n", selectedFolder!.description)
            let albums = selectedFolder!.albums as? Set<Album> ?? []
            print("albums \n", albums.description)
            

        }
        else {
            print("No selection")

        }
        
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let identifier = tableColumn?.identifier.rawValue else { return nil }
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(identifier), owner: self) as? NSTableCellView else { return nil }
        var item: NSManagedObject!
        switch tableView.identifier?.rawValue {
        case "photos":
            item = fetchedPhotosController?.fetchedObjects?[row]
        case "albums":
            item = fetchedAlbumsController?.fetchedObjects?[row]
        case "folders":
            item = fetchedFoldersController?.fetchedObjects?[row]
        default:
            print("Prax NSTableViewDataSource")
            return nil
        }
        

        if let itemValue = item.value(forKey: identifier) {

            if itemValue is String {
                cell.textField?.stringValue = itemValue as! String
            }
            else if itemValue is NSNumber {
                cell.textField?.stringValue = (itemValue as! NSNumber).stringValue
            }
            else if itemValue is Date {
                cell.textField?.stringValue = (itemValue as! Date).formatted()
            }
            else if itemValue is Folder {
                cell.textField?.stringValue = (itemValue as! Folder).title ?? "No Folder Name"
            }
            else {
                cell.textField?.stringValue = "No string value for \(identifier)"
            }
        }
        else {
            cell.textField?.stringValue = "No value for \(identifier)"
        }
        return cell
    }

    func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
        var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>?
        let key = tableColumn.identifier.rawValue
        
        print("Sorting by ", key)
        
        switch tableView.identifier?.rawValue {
            
        case "folders":
            fetchedResultsController = (fetchedFoldersController as! NSFetchedResultsController<any NSFetchRequestResult>)
     
        case "albums":
            fetchedResultsController = (fetchedAlbumsController as! NSFetchedResultsController<any NSFetchRequestResult>)

        case "photos":
            fetchedResultsController = (fetchedPhotosController as! NSFetchedResultsController<any NSFetchRequestResult>)
        default: return
            
        }
        
        let currentSort = fetchedResultsController?.fetchRequest.sortDescriptors?.first
        let ascending: Bool
        if let currentSort = currentSort, currentSort.key == key {
            ascending = !currentSort.ascending
        } else {
            ascending = true
        }
        
        fetchedResultsController?.fetchRequest.sortDescriptors = [NSSortDescriptor(key: key, ascending: ascending)]
        
        do {
            try fetchedResultsController?.performFetch()
            tableView.reloadData()
        } catch {
            print("Sorting fetch failed: \(error)")
        }

    }
    
    // (Optionally implement NSFetchedResultsControllerDelegate for more advanced updates)
 }


//  Created by Elmer Cat on 12/3/25.
//


