import PhotosUI
import SwiftUI

struct AnnouncementsView: View {
    @Environment(ADGSession.self) private var session
    @State private var viewModel = AnnouncementsViewModel()

    var body: some View {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    LazyVStack(spacing: 18) {
                        ForEach(viewModel.announcements) { announcement in
                            AnnouncementCard(
                                announcement: announcement,
                                isAdmin: session.isAdminAuthenticated,
                                onEdit: { viewModel.beginEdit(announcement) },
                                onDelete: { Task { await viewModel.delete(announcement) } }
                            )
                        }
                    }
                    .padding(ADGTheme.pagePadding)
                }
                .task { await viewModel.load() }
                .refreshable { await viewModel.load() }

                if session.isAdminAuthenticated {
                    Button {
                        viewModel.beginCreate()
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.weight(.bold))
                            .frame(width: 56, height: 56)
                            .foregroundStyle(ADGTheme.paper)
                            .background(ADGTheme.ink)
                            .clipShape(Circle())
                    }
                    .padding(24)
                }
            }
            .sheet(isPresented: $viewModel.isEditing) {
                AnnouncementEditor(viewModel: viewModel)
            }
    }
}

private struct AnnouncementCard: View {
    var announcement: Announcement
    var isAdmin: Bool
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let posterURL = announcement.posterURL {
                RemoteImageView(urlString: posterURL, aspectRatio: 3 / 4)
            }

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 8) {
                    if announcement.isPinned {
                        Text("PINNED")
                            .font(.caption2.bold())
                            .tracking(1.5)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "megaphone.fill")
                            .font(.headline)
                        Text(announcement.title)
                            .font(.title3.bold())
                            .tracking(0.2)
                                        }
                    Text(announcement.publishedAt, style: .date)
                        .font(.caption)
                        .tracking(0.8)
                        .textCase(.uppercase)
                }

                Spacer()

                if isAdmin {
                    HStack {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                        }
                        Button(role: .destructive, action: onDelete) {
                            Image(systemName: "trash")
                        }
                    }
                    .buttonStyle(.borderless)
                }
            }

            Text(announcement.body)
                .font(.body)
                .lineSpacing(5)
        }
        .padding(announcement.isPinned ? 18 : 0)
        .background(announcement.isPinned ? ADGTheme.surface : ADGTheme.paper)
        .overlay(alignment: .bottom) {
            if !announcement.isPinned {
                Rectangle()
                    .fill(ADGTheme.hairline)
                    .frame(height: 1)
                    .offset(y: 12)
            }
        }
    }
}

private struct AnnouncementEditor: View {
    @Bindable var viewModel: AnnouncementsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Copy") {
                    TextField("Title", text: $viewModel.draft.title)
                    TextEditor(text: $viewModel.draft.body)
                        .frame(minHeight: 160)
                }

                Section("Publishing") {
                    Toggle("Pin to Top", isOn: $viewModel.draft.isPinned)
                    DatePicker("Published", selection: $viewModel.draft.publishedAt)
                    Stepper("Priority \(viewModel.draft.priority)", value: $viewModel.draft.priority, in: 0...10)
                }

                Section("Poster") {
                    PhotosPicker(selection: $viewModel.selectedPhoto, matching: .images) {
                        Label("Choose Poster", systemImage: "photo")
                    }
                    if let posterURL = viewModel.draft.posterURL {
                        Text(posterURL)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Announcement")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.save()
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
