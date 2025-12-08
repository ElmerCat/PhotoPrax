//  Prax-11272
//
//  PersistenceController.swift
//  PhotoPrax
//
//  A dedicated class encapsulating the Core Data stack.

import Foundation
import CoreData

class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    private init() {
        container = NSPersistentContainer(name: "PhotoPrax")
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            
        }
        
    }
    
    // Convenience to access main context
    var context: NSManagedObjectContext {
        container.viewContext
    }
    
    // MARK: - Saving Support
    func save() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}
