import Foundation
import Observation

/// A playlist persisted locally on this Mac and never sent to YouTube Music.
struct LocalPlaylist: Codable, Hashable, Identifiable {
    let id: String
    var title: String
    var songs: [Song]
    let createdAt: Date
    var modifiedAt: Date

    var playlist: Playlist {
        Playlist(
            id: self.id,
            title: self.title,
            description: nil,
            thumbnailURL: self.songs.first?.thumbnailURL,
            trackCount: self.songs.count,
            canDelete: true
        )
    }

    var detail: PlaylistDetail {
        PlaylistDetail(
            playlist: self.playlist,
            tracks: self.songs,
            duration: self.songs.reduce(0) { $0 + ($1.duration ?? 0) }.formattedDuration
        )
    }
}

/// Persists guest-owned playlists in the app's Application Support directory.
@MainActor
@Observable
final class LocalPlaylistStore {
    static let shared = LocalPlaylistStore()

    private(set) var playlists: [LocalPlaylist] = []
    private let logger = DiagnosticsLogger.ui
    private let storageURL: URL?

    private init() {
        self.storageURL = Self.defaultStorageURL
        self.loadFromDisk()
    }

    /// Creates an isolated store that keeps playlists in memory only.
    /// Intended for tests and previews that must not access persisted user data.
    init(inMemory: Void = ()) {
        self.storageURL = nil
    }

    private static var defaultStorageURL: URL? {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        return applicationSupport
            .appendingPathComponent("Kaset", isDirectory: true)
            .appendingPathComponent("local-playlists.json")
    }

    private var persistsPlaylists: Bool {
        self.storageURL != nil
    }

    private func loadFromDisk() {
        guard let storageURL = self.storageURL,
              let data = try? Data(contentsOf: storageURL)
        else { return }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            self.playlists = try decoder.decode([LocalPlaylist].self, from: data)
        } catch {
            self.logger.error("Failed to load local playlists: \(error.localizedDescription)")
        }
    }

    private func saveToDisk() {
        guard self.persistsPlaylists, let storageURL = self.storageURL else { return }

        do {
            try FileManager.default.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .millisecondsSince1970
            let data = try encoder.encode(self.playlists)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            self.logger.error("Failed to save local playlists: \(error.localizedDescription)")
        }
    }

    var hasPlaylists: Bool {
        !self.playlists.isEmpty
    }

    func playlist(id: String) -> LocalPlaylist? {
        self.playlists.first { $0.id == id }
    }

    @discardableResult
    func create(title: String, songs: [Song]) -> Playlist? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return nil }

        let now = Date()
        let localPlaylist = LocalPlaylist(
            id: "local:\(UUID().uuidString)",
            title: trimmedTitle,
            songs: songs,
            createdAt: now,
            modifiedAt: now
        )
        self.playlists.append(localPlaylist)
        self.saveToDisk()
        return localPlaylist.playlist
    }

    func delete(id: String) {
        let originalCount = self.playlists.count
        self.playlists.removeAll { $0.id == id }
        guard self.playlists.count != originalCount else { return }
        self.saveToDisk()
    }

    func add(_ song: Song, to playlistID: String) {
        guard let index = self.playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        guard !self.playlists[index].songs.contains(where: { $0.videoId == song.videoId }) else { return }
        self.playlists[index].songs.append(song)
        self.playlists[index].modifiedAt = Date()
        self.saveToDisk()
    }

    @discardableResult
    func remove(videoID: String, from playlistID: String) -> Bool {
        guard let index = self.playlists.firstIndex(where: { $0.id == playlistID }) else { return false }

        let originalCount = self.playlists[index].songs.count
        self.playlists[index].songs.removeAll { $0.videoId == videoID }
        guard self.playlists[index].songs.count != originalCount else { return false }

        self.playlists[index].modifiedAt = Date()
        self.saveToDisk()
        return true
    }

    func detail(for playlist: Playlist) -> PlaylistDetail? {
        self.playlist(id: playlist.id)?.detail
    }

}
