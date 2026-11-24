import Foundation
import CoreData
import Combine

final class CoreDataStack: ObservableObject {

    // MARK: - Shared Instance

    static let shared = CoreDataStack()

    // MARK: - Persistent Container

    var container: NSPersistentContainer

    // MARK: - Convenience Accessor

    var context: NSManagedObjectContext {
        container.viewContext
    }

    // MARK: - Programmatic Managed Object Model (100% deterministic across iOS IPA, Xcode & SPM)

    static func makeManagedObjectModel() -> NSManagedObjectModel {
        if let modelURL = Bundle.main.url(forResource: "YTPlayer", withExtension: "momd"),
           let bundledModel = NSManagedObjectModel(contentsOf: modelURL) {
            return bundledModel
        }

        let model = NSManagedObjectModel()

        func attr(_ name: String, type: NSAttributeType, optional: Bool = false) -> NSAttributeDescription {
            let a = NSAttributeDescription()
            a.name = name
            a.attributeType = type
            a.isOptional = optional
            return a
        }

        let favoriteEntity = NSEntityDescription()
        favoriteEntity.name = "FavoriteItem"
        favoriteEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        favoriteEntity.properties = [
            attr("videoId", type: .stringAttributeType),
            attr("title", type: .stringAttributeType),
            attr("channelName", type: .stringAttributeType),
            attr("thumbnailURL", type: .stringAttributeType, optional: true),
            attr("duration", type: .stringAttributeType, optional: true),
            attr("addedAt", type: .dateAttributeType)
        ]

        let historyEntity = NSEntityDescription()
        historyEntity.name = "WatchHistoryItem"
        historyEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        historyEntity.properties = [
            attr("videoId", type: .stringAttributeType),
            attr("title", type: .stringAttributeType),
            attr("channelName", type: .stringAttributeType),
            attr("thumbnailURL", type: .stringAttributeType, optional: true),
            attr("duration", type: .stringAttributeType, optional: true),
            attr("watchedAt", type: .dateAttributeType)
        ]

        model.entities = [favoriteEntity, historyEntity]
        return model
    }

    // MARK: - Init

    private init() {
        container = NSPersistentContainer(name: "YTPlayer", managedObjectModel: Self.makeManagedObjectModel())
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                print("CoreDataStack: Store load error, falling back to in-memory store — \(error), \(error.userInfo)")
                let fallback = NSPersistentStoreDescription()
                fallback.url = URL(fileURLWithPath: "/dev/null")
                self.container.persistentStoreDescriptions = [fallback]
                self.container.loadPersistentStores { _, _ in }
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Save

    func saveContext() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            print("CoreDataStack: Failed to save context — \(nsError), \(nsError.userInfo)")
        }
    }
}
