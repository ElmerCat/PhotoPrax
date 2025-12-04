//
//  TableDataSource.swift
//  PhotoPrax

import Cocoa

class TableDataSource: NSObject, NSTableViewDataSource, NSFetchedResultsControllerDelegate {
    
    var fetchedFoldersController: NSFetchedResultsController<Folder>?
    var fetchedAlbumsController: NSFetchedResultsController<Album>?
    var fetchedPhotosController: NSFetchedResultsController<Photo>?

    override init() {
        super.init()
  
        let foldersFetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
        foldersFetchRequest.sortDescriptors = [NSSortDescriptor(key: "identifier", ascending: true)]
        let albumsFetchRequest: NSFetchRequest<Album> = Album.fetchRequest()
        albumsFetchRequest.sortDescriptors = [NSSortDescriptor(key: "identifier", ascending: true)]
        let photosFetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
        photosFetchRequest.sortDescriptors = [NSSortDescriptor(key: "identifier", ascending: true)]
        
        self.fetchedFoldersController = NSFetchedResultsController(
            fetchRequest: foldersFetchRequest, managedObjectContext: PersistenceController.shared.context, sectionNameKeyPath: nil, cacheName: nil
        )
        self.fetchedAlbumsController = NSFetchedResultsController(
            fetchRequest: albumsFetchRequest, managedObjectContext: PersistenceController.shared.context, sectionNameKeyPath: nil, cacheName: nil
        )
        self.fetchedPhotosController = NSFetchedResultsController(
            fetchRequest: photosFetchRequest, managedObjectContext: PersistenceController.shared.context, sectionNameKeyPath: nil, cacheName: nil
        )
        
        fetchedFoldersController!.delegate = self
        fetchedAlbumsController!.delegate = self
        fetchedPhotosController!.delegate = self
        
        do {
            try fetchedFoldersController!.performFetch()
            print("Folders TableDataSource Fetch performed \(fetchedFoldersController?.fetchedObjects?.count ?? 0)")
            //    photosTableView.reloadData()
        } catch {
            print("Fetch failed: \(error)")
        }
        do {
            try fetchedAlbumsController!.performFetch()
            print("Albums TableDataSource Fetch performed \(fetchedAlbumsController?.fetchedObjects?.count ?? 0)")
            //    photosTableView.reloadData()
        } catch {
            print("Fetch failed: \(error)")
        }
        do {
            try fetchedPhotosController!.performFetch()
            print("Photos TableDataSource Fetch performed \(fetchedPhotosController?.fetchedObjects?.count ?? 0)")
            //    photosTableView.reloadData()
        } catch {
            print("Fetch failed: \(error)")
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
}


extension TableDataSource: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        switch tableView.identifier?.rawValue {
        case "photos":
            
            guard let item = fetchedPhotosController?.fetchedObjects?[row],
                  let identifier = tableColumn?.identifier.rawValue else { return nil }
            
            switch identifier {
            case "identifier":
                let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(identifier), owner: self) as? NSTableCellView
                cell?.textField?.stringValue = String(item.identifier ?? "no identifier")
                return cell
            case "type":
                let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(identifier), owner: self) as? NSTableCellView
                cell?.textField?.stringValue = String(item.type)
                return cell
            default:
                return nil
            }
            
        case "albums":
            
            guard let item = fetchedAlbumsController?.fetchedObjects?[row],
                  let identifier = tableColumn?.identifier.rawValue else { return nil }
            
            switch identifier {
            case "count":
                 
                let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(identifier), owner: self) as? NSTableCellView
                cell?.textField?.stringValue = String(item.count)
                return cell
                
            case "title":
                let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(identifier), owner: self) as? NSTableCellView
                cell?.textField?.stringValue = item.title ?? "no title"
                return cell
            default:
                return nil
            }
            
        case "folders":
            
            guard let item = fetchedFoldersController?.fetchedObjects?[row],
                  let identifier = tableColumn?.identifier.rawValue else { return nil }
            
            switch identifier {
            case "title":
                let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(identifier), owner: self) as? NSTableCellView
                cell?.textField?.stringValue = String(item.title ?? "no title")
                return cell
            case "count":
                let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(identifier), owner: self) as? NSTableCellView
                cell?.textField?.stringValue = "Prax"
                return cell
            case "type":
                let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(identifier), owner: self) as? NSTableCellView
                cell?.textField?.stringValue = String(item.type)
                return cell
            default:
                return nil
            }
            
        default:
            print("Prax NSTableViewDataSource")
            return nil
        }
    }
    
    func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
        var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>?
        let key = tableColumn.identifier.rawValue
        
        print(key)
        
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


