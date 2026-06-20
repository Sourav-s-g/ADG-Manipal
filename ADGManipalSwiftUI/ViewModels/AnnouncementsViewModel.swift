import Foundation
import Observation
import PhotosUI
import SwiftUI
import UIKit

@MainActor
@Observable
final class AnnouncementsViewModel {
    var announcements: [Announcement] = []
    var draft: Announcement = .empty
    var selectedPhoto: PhotosPickerItem?
    var isEditing = false
    var isLoading = false
    var errorMessage: String?

    private let repository: ADGRepository

    init(repository: ADGRepository = .shared) {
        self.repository = repository
    }

    // MARK: - Sorted Projections for the View
    var sortedAnnouncements: [Announcement] {
        announcements.sorted {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned // Pinned items stay on top
            }
            return $0.publishedAt > $1.publishedAt // Most recent announcements next
        }
    }

    // MARK: - Actions
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            announcements = try await repository.fetchAnnouncements()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func beginCreate() {
        draft = .empty
        selectedPhoto = nil
        isEditing = true
    }

    func beginEdit(_ announcement: Announcement) {
        draft = announcement
        selectedPhoto = nil
        isEditing = true
    }

    func save() async {
        do {
            if let selectedPhoto,
               let data = try await selectedPhoto.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                draft.posterURL = try await repository.uploadJPEG(image, folder: "announcements")
            }
            
            try await repository.upsertAnnouncement(draft)
            isEditing = false
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ announcement: Announcement) async {
        do {
            try await repository.deleteAnnouncement(id: announcement.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Factory Support Extensions

private extension Announcement {
    static var empty: Announcement {
        Announcement(
            id: UUID(),
            title: "",
            body: "",
            posterURL: nil,
            isPinned: false,
            priority: 0,
            publishedAt: Date()
        )
    }
}
