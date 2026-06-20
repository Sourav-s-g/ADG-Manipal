import Foundation
import Observation
import PhotosUI
import SwiftUI
import UIKit

@MainActor
@Observable
final class EventsViewModel {
    var events: [Event] = []
    var roster: [Registration] = []
    var registeredEventIDs: Set<UUID> = []
    var searchText = ""
    var selectedSegment: EventSegment = .upcoming
    var selectedEvent: Event?
    var selectedPastEvent: Event?
    var requiresSignInForEvent: Event?
    var rosterEvent: Event?
    var draft: Event = .empty
    var isEditing = false
    var isShowingRoster = false
    var isLoading = false
    var errorMessage: String?
    var selectedPhoto: PhotosPickerItem?
    
    // Track the last active user ID to avoid wiping states on save refresh
    private var lastLoadedUserID: UUID?

    private let repository: ADGRepository

    init(repository: ADGRepository = .shared) {
        self.repository = repository
    }

    var upcomingEvents: [Event] {
        filtered(events.filter { !$0.isPast })
            .sorted { $0.startsAt < $1.startsAt }
    }

    var pastEvents: [Event] {
        filtered(events.filter(\.isPast))
            .sorted { $0.startsAt > $1.startsAt }
    }

    func load(userID: UUID? = nil) async {
        // Cache the userID context if provided, or retain previous if refreshing from draft save
        if userID != nil { self.lastLoadedUserID = userID }
        let targetUserID = userID ?? lastLoadedUserID
        
        isLoading = true
        defer { isLoading = false }
        do {
            events = try await repository.fetchEvents()
            if let targetUserID {
                registeredEventIDs = try await repository.fetchRegisteredEventIDs(userID: targetUserID)
            } else {
                registeredEventIDs = []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func beginCreate() {
        draft = .empty
        selectedPhoto = nil
        isEditing = true
    }

    func beginEdit(_ event: Event) {
        draft = event
        selectedPhoto = nil
        isEditing = true
    }

    func saveDraft() async {
        do {
            // Handle asynchronous background photo conversions & multi-part uploads safely
            if let selectedPhoto,
               let data = try await selectedPhoto.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                draft.coverImageURL = try await repository.uploadJPEG(image, folder: "events")
            }

            try await repository.upsertEvent(draft)
            isEditing = false
            
            // Reloads without wiping out user registration checkmarks
            await load(userID: lastLoadedUserID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ event: Event) async {
        do {
            try await repository.deleteEvent(id: event.id)
            await load(userID: lastLoadedUserID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func isRegistered(for event: Event) -> Bool {
        registeredEventIDs.contains(event.id)
    }

    func submitRegistration(event: Event, userID: UUID, name: String, email: String, inputs: [String: String]) async {
        do {
            _ = try await repository.register(NewRegistration(
                eventID: event.id,
                userID: userID,
                studentName: name,
                email: email,
                customInputs: inputs
            ))
            registeredEventIDs.insert(event.id)
            selectedEvent = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func filtered(_ values: [Event]) -> [Event] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return values }

        return values.filter {
            $0.title.localizedCaseInsensitiveContains(query)
        }
    }

    func refreshRegistrationState(userID: UUID?) async {
        self.lastLoadedUserID = userID
        do {
            if let userID {
                registeredEventIDs = try await repository.fetchRegisteredEventIDs(userID: userID)
            } else {
                registeredEventIDs = []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openRoster(for event: Event) async {
        do {
            rosterEvent = event
            roster = try await repository.fetchRoster(eventID: event.id)
            isShowingRoster = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Enums & Extensions

enum EventSegment: String, CaseIterable, Identifiable {
    case upcoming = "Upcoming"
    case past = "Past"
    
    var id: String { rawValue }
}

private extension Event {
    static var empty: Event {
        Event(
            id: UUID(),
            title: "",
            summary: "",
            venue: "",
            startsAt: Date().addingTimeInterval(7 * 24 * 60 * 60),
            capacity: 60,
            registeredCount: 0,
            coverImageURL: nil,
            registrationMethod: .nativeForm,
            registrationURL: nil,
            registrationEnabled: true,
            requiredFields: .standard
        )
    }
}
