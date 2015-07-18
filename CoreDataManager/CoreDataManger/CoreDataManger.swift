//
//  CoreDataManager.swift
//  Avismara
//
//  Created by Avismara on 06/07/15.
//  Copyright (c) 2015 Avismara. All rights reserved.
//

import Foundation
import UIKit
import CoreData


/**
The application's core data architecture of the app is built on -- for a lack of better nomenclature -- Child-Main-Writer pattern. An overview can be given as follows:

- There are three NSManagedObjectContext instances. `childManagedObjectContext`, `managedObjectContext` and `writerManagedObjectContext`
- The Main context is responsible for supplyings data to the UI, therefore will run unconditionally on the main thread. Do not use this context to perform heavy weight operations like inserting the data or deleting it. The most this context can do is supplying the underlying data to the UI. Any misuse of this context will cause your UI to clog or other unexpected behaviours.
- The Child context whose `parentContext` is the Main context can be used to do any heavy weight operation you want. Any code within its `performBlock(:_)` will run on the background thread and the system will handle this object's thread safety. A copy of its parent would be pulled and you can insert and delete entities from the context. Note that `NSManagedObject` or `NSManagedObjectContext` objects are **NOT** thread safe. Do **NOT** use any other contexts within its `performBlock(:_)`. Remember the CoreData rule: *One thread, one context*. Do **NOT** pass any `NSManagedObject` instances from other thread. If it is required, you can pass around the `id`s to get the `NSManagedObject` that is managed in this thread. Always, *Thread safety is more important than your safety*
- The Writer context saves the Main context to the persistant store in a background thread. Do not use this context to do your heavy database operations. Use the Child context instead.


Always use the `sharedManager` property to access these contexts.
*/
class CoreDataManager {
    
    
    /// We wouldn't want multiple instances of managed contexts running around the system. Therefore, we'll have only one instance of the DatabaseAccessLayer through which you will access the managedObjectContext
    static var sharedInstance:CoreDataManager {
        struct Static {
            static var onceToken:dispatch_once_t = 0
            static var instance:CoreDataManager? = nil
        }
        dispatch_once(&Static.onceToken) {
            Static.instance = CoreDataManager()
        }
        return Static.instance!
    }
    
    private init() {
        
    }
    
    // MARK: - Core Data stack
    
    /// The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
    lazy var managedObjectModel: NSManagedObjectModel = {
   
        let modelURL = NSBundle.mainBundle().URLForResource(CoreDataManagerConstants.APPLICATION_NAME, withExtension: "momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)!
        }()
    
    // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
  
        // Create the coordinator and store
        var coordinator: NSPersistentStoreCoordinator? = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.URLByAppendingPathComponent(CoreDataManagerConstants.APPLICATION_NAME + ".sqlite")
        var error: NSError? = nil
        var failureReason = "There was an error creating or loading the application's saved data."
        if coordinator!.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil, error: &error) == nil {
            coordinator = nil
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason
            dict[NSUnderlyingErrorKey] = error
            error = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog("Unresolved error \(error), \(error!.userInfo)")
            abort()
        }
        
        return coordinator
        }()
    
    /// `NSManagedObjectContext` that will be used to write to the Persistent Store
    private lazy var writerManagedObjectContext: NSManagedObjectContext? = {
        let coordinator = self.persistentStoreCoordinator
        if coordinator == nil {
            return nil
        }
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()
    
    ///`NSManagedObjectContext` that will be used to update the UI
    private lazy var managedObjectContext: NSManagedObjectContext? = {
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        managedObjectContext.parentContext = self.writerManagedObjectContext
        return managedObjectContext
        }()
    
    /// `NSMangedObjectContext` that will handle the background operations
    private lazy var childManagedObjectContext : NSManagedObjectContext? = {
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        managedObjectContext.parentContext = self.managedObjectContext
        return managedObjectContext
    }()
    
    // The directory the application uses to store the Core Data store file. This code uses a directory named "com.avismara.CoreDataManagerExample" in the application's documents Application Support directory.
    lazy var applicationDocumentsDirectory: NSURL = {
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1] as! NSURL
        }()
    
    /**
    Saves the given `context` to its store
    */
    func saveManagedObjectContext(context:NSManagedObjectContext?,inout error:NSError?) {
        if let moc = context {
            if moc.hasChanges && !moc.save(&error) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                abort()
            }
        }
    }
    
    /**
    Executes the given database update block in the background
    
    :param: block      The heavy database operation that you want to do in a background thread
    :param: completion The closure that will be called on completion of the operations. This is guaranteed to be called on the main thread.
    :param: failure    The closure that will be called if there were any failures in the operation. This guaranteed to be called on the main thread.
    */
    func performChildContextBlockAndSave(block:(()->()),completion:(()->()),failure:((error:NSError)->())) {
        self.childManagedObjectContext?.performBlock({ () -> Void in
            block()
            var error:NSError? = nil
            self.saveManagedObjectContext(self.childManagedObjectContext, error:&error)
            self.managedObjectContext?.performBlock({ () -> Void in
                self.saveManagedObjectContext(self.managedObjectContext, error:&error)
                self.writerManagedObjectContext?.performBlock({ () -> Void in
                    self.saveManagedObjectContext(self.writerManagedObjectContext, error:&error)
                    performClosureOnMainThread({ () -> () in
                        if error != nil {
                            failure(error: error!)
                        } else {
                            completion()
                        }
                        
                    })
                })
            })
        })
    }
    
    /**
    Executes the given database fetch block in the main thread
    
    :param: block      The light operation that you want to do in the main thread
    :param: completion The callback that will be called after the process was completed
    :param: failure    The closure that will be called if there were any failures in the operation. This is guaranteed to run on the main thread.
    */
    func performMainContextBlockAndSave(block:(()->()),completion:(()->()),failure:((error:NSError)->())) {
        self.managedObjectContext?.performBlock({ () -> Void in
            block()
            var error:NSError? = nil
            self.saveManagedObjectContext(self.managedObjectContext, error:&error)
            self.writerManagedObjectContext?.performBlock({ () -> Void in
                self.saveManagedObjectContext(self.writerManagedObjectContext, error:&error)
                performClosureOnMainThread({ () -> () in
                    if error != nil {
                        failure(error: error!)
                    } else {
                        completion()
                    }
                    
                })
                
            })
        })
    }
    
    /**
    Saves the `writeContext` to persistent store coordinator
    */
    func saveWriteContext(completion:(()->()),failure:((error:NSError)->())) {
        var error:NSError? = nil
        self.saveManagedObjectContext(self.managedObjectContext, error:&error)
        self.writerManagedObjectContext?.performBlock({ () -> Void in
            self.saveManagedObjectContext(self.writerManagedObjectContext, error:&error)
            performClosureOnMainThread({ () -> () in
                if error != nil {
                    failure(error: error!)
                } else {
                    completion()
                }
                
            })
            
        })
        
    }
    
    
    
    /**
    A convenience method that creates an instance of NSManagedObject. This removes code duplication of creating an entity everytime you want to insert a managed object to the context.
    
    :param: name The name of NSManageObject entity
    
    :returns: The instance of NSManagedObject of the entity with name.
    */
    func insertManagedObjectForEntityWithName(name:String) -> NSManagedObject {
        var managedObject:NSManagedObject!
        let entity = NSEntityDescription.entityForName(name, inManagedObjectContext:self.childManagedObjectContext!)
        managedObject = NSManagedObject(entity: entity!, insertIntoManagedObjectContext:self.childManagedObjectContext!)
        return managedObject
    }
    
    
    /**
    Deletes all the entities in the DB as given the entity name
    
    :param: name Name of the Entity which has to be deleted
    */
    func deleteManagedObjectsForEntityWithName(name:String) {
        let entity = NSEntityDescription.entityForName(name, inManagedObjectContext:self.childManagedObjectContext!)
        let fetchRequest = NSFetchRequest()
        fetchRequest.entity = entity
        
        var error:NSError? = nil
        let managedObjects = self.childManagedObjectContext?.executeFetchRequest(fetchRequest, error:&error)
        if let objects = managedObjects {
            for object in objects {
                self.childManagedObjectContext?.deleteObject(object as! NSManagedObject)
            }
        }
    }
    
    /**
    Returns all the entities of the given `entityName`
    */
    func retrieveManagedObjectForEntityWithName<T:NSManagedObject>(entityName:String, failure:((error:NSError) -> ())) -> [T] {
        return retrieveManagedObjectsWithPredicate(nil, forEntityWithName: entityName,failure:failure)
    }
    
    /**
    Returns an array of managed objects with the given predicate on a given entity. Use this method to retrieve objects of a single entity as given by the generics.
    
    :param: predicate  A predicate with filtering rules
    :param: entityName The entity
    
    :returns: Return an array of NSManagedObject as given by the generics.
    */
    func retrieveManagedObjectsWithPredicate<T:NSManagedObject>(predicate:NSPredicate?, forEntityWithName entityName:String, failure:((error:NSError) -> ())) -> [T] {
        let fetchRequest = NSFetchRequest()
        fetchRequest.predicate = predicate
        return retrieveManagedObjectsWithFetchRequest(fetchRequest, forEntityWithName: entityName,failure:failure)
    }
    
    /**
    Returns an array of managed objects with the given fetchRequest on a given entity. Use this method to retrieve objects of a single entity as given by the generics.
    
    :param: fetchRequest  A fetch request with filtering rules
    :param: entityName The entity
    
    :returns: Return an array of NSManagedObject as given by the generics.
    */
    func retrieveManagedObjectsWithFetchRequest<T:NSManagedObject>(fetchRequest:NSFetchRequest, forEntityWithName entityName:String, failure:((error:NSError) -> ())) -> [T] {
        
        var managedObjects = [T]()
       
            let entity = NSEntityDescription.entityForName(entityName, inManagedObjectContext:self.managedObjectContext!)
            fetchRequest.entity = entity
            var error:NSError? = nil
            managedObjects = (self.managedObjectContext?.executeFetchRequest(fetchRequest, error:&error) as? [T])!
            if let err = error {
                println(err)
                failure(error:err)
                //TODO: Investigate the error during development. Uncomment the //return [T]() statement in production
                fatalError("An error occured while fetching")
                //return [T]()
            }
        return managedObjects
    }
    
    /**
    Returns the `NSEntityDescription` instance for the given `entityName`
    */
    func entityDescriptionForEntityWithName(entityName:String) -> NSEntityDescription {
        return NSEntityDescription.entityForName(entityName, inManagedObjectContext:managedObjectContext!)!
    }
    
    /**
    Returns an instance of `NSFetchedResultsController` instantiated with the given `fetchRequest` and the `cache`
    */
    func fetchedResultsControllerWithFetchRequest(fetchRequest:NSFetchRequest,cacheName:String?) -> NSFetchedResultsController {
        var fetchedResultsController:NSFetchedResultsController!
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedObjectContext!, sectionNameKeyPath: nil, cacheName: cacheName)
        
        return fetchedResultsController
    }
    
    
}