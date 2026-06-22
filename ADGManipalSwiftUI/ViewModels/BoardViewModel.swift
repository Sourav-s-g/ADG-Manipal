import Foundation
import Observation
import PhotosUI
import SwiftUI
import UIKit

@MainActor
@Observable
final class BoardViewModel {
    // MARK: - Core Board State
    var members: [BoardMember] = []
    var selectedMember: BoardMember?
    var draft: BoardMember = .empty
    var selectedPhoto: PhotosPickerItem?
    var isEditing = false
    var isLoading = false
    var errorMessage: String?
    
    // MARK: - About Us Text State
    var aboutText: String = defaultAboutText
    var aboutDraft: String = ""
    var isEditingAboutText = false
    
    // MARK: - App Feedback State
    var feedbackEmail: String = ""
    var feedbackMessage: String = ""
    var isSubmittingFeedback = false
    var feedbackSuccessMessage: String?

    private let repository: ADGRepository

    init(repository: ADGRepository = .shared) {
        self.repository = repository
    }
    
    // MARK: - Filtered & Sorted Projections
    var currentMembers: [BoardMember] {
        members
            .filter { $0.isCurrent }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var previousMembers: [BoardMember] {
        members
            .filter { !$0.isCurrent }
            .sorted {
                if $0.boardYear == $1.boardYear {
                    return $0.sortOrder < $1.sortOrder
                }
                return $0.boardYear > $1.boardYear // Group by newest alumni years first
            }
    }

    // MARK: - Load Logic
    func load() async {
        isLoading = true
        defer { isLoading = false }

        // Fetch board members
        do {
            members = try await repository.fetchBoardMembers()
        } catch {
            errorMessage = error.localizedDescription
        }

        // Fetch custom about text copy
        do {
            aboutText = try await repository.fetchAboutText()
        } catch {
            aboutText = Self.defaultAboutText
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - About Us Operations
    func beginAboutEdit() {
        aboutDraft = aboutText
        isEditingAboutText = true
    }

    func saveAboutText() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await repository.updateAboutText(aboutDraft)
            aboutText = aboutDraft
            isEditingAboutText = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Feedback Operations
    func submitFeedback(currentUserID: UUID?) async {
        let trimmedEmail = feedbackEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMessage = feedbackMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedEmail.isEmpty, !trimmedMessage.isEmpty else { return }
        
        isSubmittingFeedback = true
        defer { isSubmittingFeedback = false }
        
        do {
            // Pushes directly down into your Supabase/PostgreSQL repository pipeline
            try await repository.submitFeedback(
                email: trimmedEmail,
                message: trimmedMessage,
                userID: currentUserID
            )
            
            // Wipe form input fields on successful database response
            feedbackEmail = ""
            feedbackMessage = ""
            feedbackSuccessMessage = "Thank you! Your feedback has been sent directly to the core team."
            
            // Automatic contextual reset for the success message toast banner
            // Sleep and then reset on main thread to avoid threading issues
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                self.feedbackSuccessMessage = nil
            }
        } catch {
            errorMessage = "Failed to send feedback: \(error.localizedDescription)"
        }
    }

    // MARK: - Board Member Operations
    func beginCreate() {
        draft = .empty
        // Safely set the new sequence order index position
        draft.sortOrder = (members.map(\.sortOrder).max() ?? -1) + 1
        selectedPhoto = nil
        isEditing = true
    }

    func beginEdit(_ member: BoardMember) {
        draft = member
        selectedPhoto = nil
        isEditing = true
    }

    /// Handles reordering inside lists without crushing the network engine
    func move(from source: IndexSet, to destination: Int) async {
        // Perform local mutation instantly for fluid UI responsiveness
        members.move(fromOffsets: source, toOffset: destination)
        
        // Update sort assignments structurally
        for index in members.indices {
            members[index].sortOrder = index
        }
        
        do {
            // Note: If your repository exposes a batch update method like `upsertBoardMembers(_:)`,
            // swap this out to process a single network request instead of a sequential loop.
            for member in members {
                try await repository.upsertBoardMember(member)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() async {
        do {
            if let selectedPhoto,
               let data = try await selectedPhoto.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                draft.headshotURL = try await repository.uploadJPEG(image, folder: "board")
            }
            
            try await repository.upsertBoardMember(draft)
            isEditing = false
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ member: BoardMember) async {
        do {
            try await repository.deleteBoardMember(id: member.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Default Constants & Factory Support

private extension BoardViewModel {
    static let defaultAboutText = "Apple Developers Group is a student community at MIT Manipal focused on building thoughtful products, learning Apple technologies, and growing together through events, workshops, and projects."
}

private extension BoardMember {
    static var empty: BoardMember {
        BoardMember(
            id: UUID(),
            name: "",
            role: "",
            domain: "",
            bio: "",
            headshotURL: nil,
            githubURL: nil,
            linkedInURL: nil,
            sortOrder: 0,
            boardYear: "2026",
            isCurrent: true
        )
    }
}
