import Foundation
import Supabase
import UIKit

actor ADGRepository {
    static let shared = ADGRepository()

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseProvider.shared) {
        self.client = client
    }

    func fetchAnnouncements() async throws -> [Announcement] {
        try await client
            .from("announcements")
            .select()
            .order("is_pinned", ascending: false)
            .order("published_at", ascending: false)
            .execute()
            .value
    }
    
    // MARK: - App Feedback Operation
        /// Pushes user feedback records directly to the backend database table
        func submitFeedback(email: String, message: String, userID: UUID?) async throws {
            let feedbackDTO = FeedbackUploadDTO(
                email: email,
                message: message,
                userId: userID
            )
            
            try await client
                .from("app_feedback")
                .insert(feedbackDTO)
                .execute()
        }
    
    func fetchAboutText() async throws -> String {
        do {
            let config: AppConfig = try await client
                .from("app_config")
                .select()
                .eq("id", value: "about_us")
                .single()
                .execute()
                .value

            return config.aboutText
        } catch {
            return "Apple Developers Group is a student community at MIT Manipal focused on building thoughtful products, learning Apple technologies, and growing together through events, workshops, and projects."
        }
    }

    func updateAboutText(_ newText: String) async throws {
        let config = AppConfig(id: "about_us", aboutText: newText)
        try await client
            .from("app_config")
            .upsert(config)
            .execute()
    }

    func upsertAnnouncement(_ announcement: Announcement) async throws {
        try await client.from("announcements").upsert(announcement).execute()
    }

    func deleteAnnouncement(id: UUID) async throws {
        try await client.from("announcements").delete().eq("id", value: id).execute()
    }

    func fetchEvents() async throws -> [Event] {
        try await client
            .from("events")
            .select()
            .order("starts_at", ascending: true)
            .execute()
            .value
    }

    func upsertEvent(_ event: Event) async throws {
        try await client.from("events").upsert(event).execute()
    }

    func deleteEvent(id: UUID) async throws {
        try await client.from("events").delete().eq("id", value: id).execute()
    }

    func register(_ registration: NewRegistration) async throws -> Registration {
        let saved: Registration = try await client
            .from("registrations")
            .insert(registration)
            .select()
            .single()
            .execute()
            .value

        return saved
    }

    func fetchRegisteredEventIDs(userID: UUID) async throws -> Set<UUID> {
        let rows: [RegisteredEvent] = try await client
            .from("registrations")
            .select("event_id")
            .eq("user_id", value: userID)
            .execute()
            .value

        return Set(rows.map(\.eventID))
    }

    func fetchRoster(eventID: UUID) async throws -> [Registration] {
        try await client
            .from("registrations")
            .select()
            .eq("event_id", value: eventID)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func fetchBoardMembers() async throws -> [BoardMember] {
        try await client
            .from("board_members")
            .select()
            .order("sort_order", ascending: true)
            .execute()
            .value
    }

    func upsertBoardMember(_ member: BoardMember) async throws {
        try await client.from("board_members").upsert(member).execute()
    }

    func deleteBoardMember(id: UUID) async throws {
        try await client.from("board_members").delete().eq("id", value: id).execute()
    }

    func uploadJPEG(_ image: UIImage, folder: String) async throws -> String {
        let preparedImage = image.croppedAndResized(toAspectRatio: 3 / 4, maxPixelHeight: 1600)
        guard let data = preparedImage.jpegData(compressionQuality: 0.78) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let path = "\(folder)/\(UUID().uuidString).jpg"
        try await client.storage
            .from(SupabaseConfiguration.assetBucket)
            .upload(
                path,
                data: data,
                options: FileOptions(
                    cacheControl: "604800",
                    contentType: "image/jpeg",
                    upsert: false
                )
            )

        return try client.storage
            .from(SupabaseConfiguration.assetBucket)
            .getPublicURL(path: path)
            .absoluteString
    }

}

private extension UIImage {
    func croppedAndResized(toAspectRatio targetRatio: CGFloat, maxPixelHeight: CGFloat) -> UIImage {
        let sourceSize = size
        let sourceRatio = sourceSize.width / sourceSize.height
        let cropRect: CGRect

        if sourceRatio > targetRatio {
            let width = sourceSize.height * targetRatio
            cropRect = CGRect(x: (sourceSize.width - width) / 2, y: 0, width: width, height: sourceSize.height)
        } else {
            let height = sourceSize.width / targetRatio
            cropRect = CGRect(x: 0, y: (sourceSize.height - height) / 2, width: sourceSize.width, height: height)
        }

        let outputHeight = min(maxPixelHeight, cropRect.height * scale)
        let outputWidth = outputHeight * targetRatio
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: CGSize(width: outputWidth, height: outputHeight), format: format).image { _ in
            draw(
                in: CGRect(
                    x: -cropRect.origin.x * (outputWidth / cropRect.width),
                    y: -cropRect.origin.y * (outputHeight / cropRect.height),
                    width: sourceSize.width * (outputWidth / cropRect.width),
                    height: sourceSize.height * (outputHeight / cropRect.height)
                )
            )
        }
    }
}

// MARK: - Feedback Data Transfer Object
private struct FeedbackUploadDTO: Encodable {
    let email: String
    let message: String
    
    /// Matches database layout naming conventions seamlessly via custom coding keys
    let userId: UUID?

    enum CodingKeys: String, CodingKey {
        case email
        case message
        case userId = "user_id"
    }
}
