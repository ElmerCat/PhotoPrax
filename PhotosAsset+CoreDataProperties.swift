//
//  PhotosAsset+CoreDataProperties.swift
//  PhotoPrax
//
//  Created by Elmer Cat on 11/27/25.
//
//

public import Foundation
public import CoreData


public typealias PhotosAssetCoreDataPropertiesSet = NSSet

extension PhotosAsset {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PhotosAsset> {
        return NSFetchRequest<PhotosAsset>(entityName: "PhotosAsset")
    }

    @NSManaged public var identifier: String?
    @NSManaged public var mediaType: String?
    @NSManaged public var creationDate: Date?
    @NSManaged public var modificationDate: Date?
    @NSManaged public var collections: NSSet?

}

// MARK: Generated accessors for collections
extension PhotosAsset {

    @objc(addCollectionsObject:)
    @NSManaged public func addToCollections(_ value: AssetCollection)

    @objc(removeCollectionsObject:)
    @NSManaged public func removeFromCollections(_ value: AssetCollection)

    @objc(addCollections:)
    @NSManaged public func addToCollections(_ values: NSSet)

    @objc(removeCollections:)
    @NSManaged public func removeFromCollections(_ values: NSSet)

}

extension PhotosAsset : Identifiable {

}
