import PhotosUI
import SwiftUI
import Foundation

struct AboutUsView: View {
    @Environment(ADGSession.self) private var session
    @State private var viewModel = BoardViewModel()
    @State private var expandedPreviousMemberIDs: Set<UUID> = []

    var body: some View {
        // 🔘 Removed NavigationStack wrapper to eliminate UIKit layout collisions
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Text(viewModel.aboutText)
                        .font(.body)
                        .lineSpacing(5)
                        .foregroundStyle(ADGTheme.ink.opacity(0.75))
                        .animation(.default, value: viewModel.aboutText) // Clean fade upon dynamic update
                    
                    if session.isAdminAuthenticated {
                        Spacer()
                        
                        Button {
                            viewModel.aboutDraft = viewModel.aboutText
                            viewModel.isEditingAboutText = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundStyle(ADGTheme.ink)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, ADGTheme.pagePadding)
            .padding(.top, 18)
            
            VStack(alignment: .leading, spacing: 24) {
                Text("Core Board")
                    .font(.largeTitle.bold())
                    .tracking(0.3)
                    .padding(.horizontal, ADGTheme.pagePadding)
                    .padding(.top, 18)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 24) {
                    ForEach(viewModel.currentMembers) { member in
                        BoardMemberTile(
                            member: member,
                            isAdmin: session.isAdminAuthenticated,
                            onSelect: { viewModel.selectedMember = member },
                            onEdit: { viewModel.beginEdit(member) },
                            onDelete: { Task { await viewModel.delete(member) } }
                        )
                    }
                }
                .padding(.horizontal, ADGTheme.pagePadding)
                
                if !viewModel.previousMembers.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Previous Boards")
                            .font(.title.bold())
                            .tracking(0.3)

                        ForEach(viewModel.previousMembers) { member in
                            PreviousBoardMemberRow(
                                member: member,
                                isExpanded: expandedPreviousMemberIDs.contains(member.id),
                                isAdmin: session.isAdminAuthenticated,
                                onToggle: { togglePreviousMember(member.id) },
                                onEdit: { viewModel.beginEdit(member) },
                                onDelete: { Task { await viewModel.delete(member) } }
                            )
                        }
                    }
                    .padding(.horizontal, ADGTheme.pagePadding)
                }
            }
            .padding(.bottom, 90)
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .safeAreaInset(edge: .bottom, alignment: .trailing) {
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
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
        }
        // 🔘 Removed .navigationTitle and .navigationBarTitleDisplayMode from main content view tree
        .sheet(isPresented: $viewModel.isEditing) {
            BoardMemberEditor(viewModel: viewModel)
        }
        .sheet(item: $viewModel.selectedMember) { member in
            BoardMemberDetail(member: member)
        }
        .sheet(isPresented: $viewModel.isEditingAboutText) {
            NavigationStack {
                Form {
                    Section("Edit Community Description") {
                        TextField("About Us Text", text: $viewModel.aboutDraft, axis: .vertical)
                            .lineLimit(6...12)
                    }
                }
                .navigationTitle("About Us")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { viewModel.isEditingAboutText = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task {
                                await viewModel.saveAboutText()
                                viewModel.isEditingAboutText = false
                            }
                        }
                    }
                }
            }
        }
    }

    private func togglePreviousMember(_ id: UUID) {
        if expandedPreviousMemberIDs.contains(id) {
            expandedPreviousMemberIDs.remove(id)
        } else {
            expandedPreviousMemberIDs.insert(id)
        }
    }
}

// MARK: - Secondary Subviews

private struct BoardMemberTile: View {
    var member: BoardMember
    var isAdmin: Bool
    var onSelect: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onSelect) {
                RemoteImageView(urlString: member.headshotURL, aspectRatio: 3 / 4)
            }
            .buttonStyle(.plain)

            Text(member.name)
                .font(.headline)
            Text(member.domain)
                .font(.caption.weight(.medium))
                .tracking(1.1)
                .textCase(.uppercase)

            if isAdmin {
                HStack {
                    Button(action: onEdit) { Image(systemName: "pencil") }
                    Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

private struct BoardMemberDetail: View {
    var member: BoardMember
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                RemoteImageView(urlString: member.headshotURL, aspectRatio: 3 / 4)
                    .aspectRatio(3 / 4, contentMode: .fit)
                    .cornerRadius(8)

                Text(member.name)
                    .font(.largeTitle.bold())
                Text("\(member.role) / \(member.domain)")
                    .font(.caption.weight(.medium))
                    .tracking(1.2)
                    .textCase(.uppercase)
                Rectangle()
                    .fill(ADGTheme.ink)
                    .frame(height: 1)
                Text(member.bio)
                    .font(.body)
                    .lineSpacing(5)

                HStack(spacing: 12) {
                    linkButton("GitHub", systemImage: "chevron.left.forwardslash.chevron.right", url: member.githubURL)
                    linkButton("LinkedIn", systemImage: "person.text.rectangle", url: member.linkedInURL)
                }
            }
            .padding(ADGTheme.pagePadding)
        }
        .background(ADGTheme.paper)
    }

    @ViewBuilder
    private func linkButton(_ title: String, systemImage: String, url: String?) -> some View {
        if let url, let value = URL(string: url) {
            Button {
                UIApplication.shared.open(value)
            } label: {
                Label(title, systemImage: systemImage)
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .textCase(.uppercase)
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .foregroundStyle(ADGTheme.paper)
                    .background(ADGTheme.ink)
            }
        }
    }
}

private struct PreviousBoardMemberRow: View {
    var member: BoardMember
    var isExpanded: Bool
    var isAdmin: Bool
    var onToggle: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onToggle) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.name)
                            .font(.headline)

                        Text("\(member.role) / \(member.boardYear) / \(member.domain)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    if !member.bio.isEmpty {
                        Text(member.bio)
                            .font(.body)
                            .lineSpacing(4)
                    }

                    HStack(spacing: 12) {
                        linkButton("GitHub", systemImage: "chevron.left.forwardslash.chevron.right", url: member.githubURL)
                        linkButton("LinkedIn", systemImage: "person.text.rectangle", url: member.linkedInURL)
                    }

                    if isAdmin {
                        HStack {
                            Button(action: onEdit) {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive, action: onDelete) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(ADGTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .animation(.easeInOut(duration: 0.18), value: isExpanded)
    }

    @ViewBuilder
    private func linkButton(_ title: String, systemImage: String, url: String?) -> some View {
        if let url, let value = URL(string: url) {
            Button {
                UIApplication.shared.open(value)
            } label: {
                Label(title, systemImage: systemImage)
            }
            .font(.caption.weight(.semibold))
        }
    }
}

private struct BoardMemberEditor: View {
    @Bindable var viewModel: BoardViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $viewModel.draft.name)
                        .autocorrectionDisabled()
                    TextField("Role", text: $viewModel.draft.role)
                    TextField("Domain", text: $viewModel.draft.domain)
                    TextField("Bio", text: $viewModel.draft.bio, axis: .vertical)
                    TextField("Board Year", text: $viewModel.draft.boardYear)
                    Toggle("Current Board Member", isOn: $viewModel.draft.isCurrent)
                    Stepper("Sort Order \(viewModel.draft.sortOrder)", value: $viewModel.draft.sortOrder, in: 0...100)
                }

                Section("Links") {
                    optionalField("GitHub URL", value: $viewModel.draft.githubURL)
                    optionalField("LinkedIn URL", value: $viewModel.draft.linkedInURL)
                }

                Section("Headshot") {
                    PhotosPicker(selection: $viewModel.selectedPhoto, matching: .images) {
                        Label("Choose Headshot", systemImage: "photo")
                    }
                }
            }
            .navigationTitle("Board Member")
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

    private func optionalField(_ title: String, value: Binding<String?>) -> some View {
        TextField(title, text: Binding(
            get: { value.wrappedValue ?? "" },
            set: { value.wrappedValue = $0.isEmpty ? nil : $0 }
        ))
    }
}
