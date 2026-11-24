import Foundation
import CoreData
import Combine

struct UserPlaylist: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var items: [VideoItem]
}

final class LibraryRepository: ObservableObject {

    private let context: NSManagedObjectContext
    private let playlistsDefaultsKey = "ytplayer_user_playlists_v1"

    init(context: NSManagedObjectContext = CoreDataStack.shared.context) {
        self.context = context
    }

    // MARK: - Playlists (Persisted via Codable JSON)

    func fetchPlaylists() -> [UserPlaylist] {
        guard let data = UserDefaults.standard.data(forKey: playlistsDefaultsKey),
              let decoded = try? JSONDecoder().decode([UserPlaylist].self, from: data) else {
            return []
        }
        return decoded
    }

    func createPlaylist(name: String, initialVideo: VideoItem? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var list = fetchPlaylists()
        let newPl = UserPlaylist(
            id: UUID().uuidString,
            name: trimmed,
            items: initialVideo.map { [$0] } ?? []
        )
        list.insert(newPl, at: 0)
        savePlaylists(list)
    }

    func toggleVideo(_ video: VideoItem, inPlaylistId playlistId: String) {
        var list = fetchPlaylists()
        guard let idx = list.firstIndex(where: { $0.id == playlistId }) else { return }
        if let vIdx = list[idx].items.firstIndex(where: { $0.id == video.id }) {
            list[idx].items.remove(at: vIdx)
        } else {
            list[idx].items.insert(video, at: 0)
        }
        savePlaylists(list)
    }

    func deletePlaylist(id: String) {
        var list = fetchPlaylists()
        list.removeAll { $0.id == id }
        savePlaylists(list)
    }

    private func savePlaylists(_ list: [UserPlaylist]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: playlistsDefaultsKey)
            objectWillChange.send()
        }
    }

    // MARK: - Favorites

    func addFavorite(_ video: VideoItem) throws {
        if isFavorite(videoId: video.id) { return }

        let entity = NSEntityDescription.insertNewObject(
            forEntityName: "FavoriteItem",
            into: context
        )
        entity.setValue(video.id, forKey: "videoId")
        entity.setValue(video.title, forKey: "title")
        entity.setValue(video.channelName, forKey: "channelName")
        entity.setValue(video.thumbnailURL, forKey: "thumbnailURL")
        entity.setValue(video.duration, forKey: "duration")
        entity.setValue(Date(), forKey: "addedAt")

        try context.save()
        objectWillChange.send()
    }

    func removeFavorite(videoId: String) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: "FavoriteItem")
        request.predicate = NSPredicate(format: "videoId == %@", videoId)

        let results = try context.fetch(request)
        results.forEach { context.delete($0) }

        if context.hasChanges {
            try context.save()
            objectWillChange.send()
        }
    }

    func isFavorite(videoId: String) -> Bool {
        let request = NSFetchRequest<NSManagedObject>(entityName: "FavoriteItem")
        request.predicate = NSPredicate(format: "videoId == %@", videoId)
        request.fetchLimit = 1

        let count = (try? context.count(for: request)) ?? 0
        return count > 0
    }

    func fetchFavorites() -> [VideoItem] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "FavoriteItem")
        request.sortDescriptors = [
            NSSortDescriptor(key: "addedAt", ascending: false)
        ]

        guard let results = try? context.fetch(request) else { return [] }
        return results.compactMap { mapToVideoItem(from: $0) }
    }

    // MARK: - Watch History

    func addToHistory(_ video: VideoItem) throws {
        let existingRequest = NSFetchRequest<NSManagedObject>(entityName: "WatchHistoryItem")
        existingRequest.predicate = NSPredicate(format: "videoId == %@", video.id)
        existingRequest.fetchLimit = 1

        if let existing = try context.fetch(existingRequest).first {
            existing.setValue(Date(), forKey: "watchedAt")
            existing.setValue(video.title, forKey: "title")
            existing.setValue(video.channelName, forKey: "channelName")
            existing.setValue(video.thumbnailURL, forKey: "thumbnailURL")
            existing.setValue(video.duration, forKey: "duration")
        } else {
            let entity = NSEntityDescription.insertNewObject(
                forEntityName: "WatchHistoryItem",
                into: context
            )
            entity.setValue(video.id, forKey: "videoId")
            entity.setValue(video.title, forKey: "title")
            entity.setValue(video.channelName, forKey: "channelName")
            entity.setValue(video.thumbnailURL, forKey: "thumbnailURL")
            entity.setValue(video.duration, forKey: "duration")
            entity.setValue(Date(), forKey: "watchedAt")
        }

        try context.save()
        objectWillChange.send()
    }

    func removeHistoryItem(videoId: String) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: "WatchHistoryItem")
        request.predicate = NSPredicate(format: "videoId == %@", videoId)

        let results = try context.fetch(request)
        results.forEach { context.delete($0) }

        if context.hasChanges {
            try context.save()
            objectWillChange.send()
        }
    }

    func fetchHistory() -> [VideoItem] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "WatchHistoryItem")
        request.sortDescriptors = [
            NSSortDescriptor(key: "watchedAt", ascending: false)
        ]

        guard let results = try? context.fetch(request) else { return [] }
        return results.compactMap { mapToVideoItem(from: $0) }
    }

    func clearHistory() throws {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "WatchHistoryItem")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        deleteRequest.resultType = .resultTypeObjectIDs

        let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
        let objectIDs = result?.result as? [NSManagedObjectID] ?? []

        let changes = [NSDeletedObjectsKey: objectIDs]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
        objectWillChange.send()
    }

    private func mapToVideoItem(from object: NSManagedObject) -> VideoItem? {
        guard
            let videoId = object.value(forKey: "videoId") as? String,
            let title = object.value(forKey: "title") as? String,
            let channelName = object.value(forKey: "channelName") as? String
        else { return nil }

        let thumbnailURL = (object.value(forKey: "thumbnailURL") as? String)
            ?? "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg"
        let duration = (object.value(forKey: "duration") as? String) ?? ""

        return VideoItem(
            id: videoId,
            title: title,
            channelName: channelName,
            channelId: "",
            thumbnailURL: thumbnailURL,
            duration: duration,
            viewCount: "",
            publishedAt: "",
            description: ""
        )
    }
}
