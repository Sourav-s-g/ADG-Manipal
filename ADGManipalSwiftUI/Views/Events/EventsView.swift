import SwiftUI
import PhotosUI

struct EventsView: View {
    @Environment(ADGSession.self) private var session
    @State private var viewModel = EventsViewModel()
    @State private var safariURL: IdentifiableURL?
    @State private var showsSignInSheet = false

    var body: some View {
        ScrollView {
            // MARK: - Search & Admin Row
            HStack(spacing: 12) {
                // Custom Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Search events", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .frame(height: 50)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                
                // Inline Admin Add Button
                if session.isAdminAuthenticated {
                    Button {
                        viewModel.beginCreate()
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.bold))
                            .frame(width: 50, height: 50)
                            .foregroundStyle(ADGTheme.paper)
                            .background(ADGTheme.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }
            }
            .padding(.horizontal, ADGTheme.pagePadding)
            .padding(.top, 16)
            
            // MARK: - Segmented Control
            Picker("Event Segment", selection: $viewModel.selectedSegment) {
                ForEach(EventSegment.allCases) { segment in
                    Text(segment.rawValue).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, ADGTheme.pagePadding)
            .padding(.top, 16)

            // MARK: - Content Switcher
            if viewModel.selectedSegment == .upcoming {
                if viewModel.upcomingEvents.isEmpty {
                    GeometryReader { geometry in
                        NoUpcomingEventsView()
                            .frame(width: geometry.size.width, height: max(400, geometry.size.height - 100))
                    }
                    .frame(minHeight: 450)
                } else {
                    LazyVStack(spacing: 18) {
                        ForEach(viewModel.upcomingEvents) { event in
                            UpcomingEventCard(
                                event: event,
                                isAdmin: session.isAdminAuthenticated,
                                isRegistered: viewModel.isRegistered(for: event),
                                onRegister: { handleRegistration(event) },
                                onEdit: { viewModel.beginEdit(event) },
                                onDelete: { Task { await viewModel.delete(event) } },
                                onRoster: { Task { await viewModel.openRoster(for: event) } }
                            )
                        }
                    }
                    .padding(ADGTheme.pagePadding)
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 14)], spacing: 14) {
                    ForEach(viewModel.pastEvents) { event in
                        Button {
                            viewModel.selectedPastEvent = event
                        } label: {
                            PastEventTile(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(ADGTheme.pagePadding)
            }
        }
        // Removed .navigationTitle and .navigationBarTitleDisplayMode to clear out navigation stack logs
        .task { await viewModel.load(userID: session.userID) }
        .refreshable { await viewModel.load(userID: session.userID) }
        .onChange(of: session.userID) { _, userID in
            Task { await viewModel.refreshRegistrationState(userID: userID) }
        }
        
        // MARK: - Presentation Sheets & Overlays
        .sheet(item: $viewModel.selectedEvent) { event in
            RegistrationSheet(event: event, initialEmail: session.userEmail ?? "") { name, email, inputs in
                guard let userID = session.userID else { return }
                await viewModel.submitRegistration(event: event, userID: userID, name: name, email: email, inputs: inputs)
            }
        }
        .sheet(isPresented: $showsSignInSheet) {
            AdminLoginSheet()
                .presentationDetents([.height(430)])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $safariURL) { url in
            SafariView(url: url.url)
        }
        .sheet(isPresented: $viewModel.isEditing) {
            EventEditor(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isShowingRoster) {
            RosterView(event: viewModel.rosterEvent, registrations: viewModel.roster)
        }
        .sheet(item: $viewModel.selectedPastEvent) { event in
            PastEventDetailPanel(
                event: event,
                isAdmin: session.isAdminAuthenticated,
                onRoster: { Task { await viewModel.openRoster(for: event) } }
            )
        }
        .alert("Sign in to register", isPresented: Binding(
            get: { viewModel.requiresSignInForEvent != nil },
            set: { if !$0 { viewModel.requiresSignInForEvent = nil } }
        )) {
            Button("Sign In") {
                viewModel.requiresSignInForEvent = nil
                showsSignInSheet = true
            }
            Button("Cancel", role: .cancel) {
                viewModel.requiresSignInForEvent = nil
            }
        } message: {
            Text("Create or sign in to your student account before registering for an event.")
        }
    }

    private func handleRegistration(_ event: Event) {
        guard !viewModel.isRegistered(for: event) else { return }
        guard session.isAuthenticated else {
            viewModel.requiresSignInForEvent = event
            return
        }

        switch event.registrationMethod {
        case .externalLink:
            if let value = event.registrationURL, let url = URL(string: value) {
                safariURL = IdentifiableURL(url: url)
            }
        case .nativeForm:
            viewModel.selectedEvent = event
        }
    }
}

// MARK: - Subviews

private struct UpcomingEventCard: View {
    var event: Event
    var isAdmin: Bool
    var isRegistered: Bool
    var onRegister: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onRoster: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RemoteImageView(urlString: event.coverImageURL, aspectRatio: 3 / 4)
                .frame(maxWidth: .infinity)
                .aspectRatio(3 / 4, contentMode: .fit)
                .contentShape(Rectangle())
                .clipped()
                .cornerRadius(8)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    if event.isLive {
                        Text("LIVE")
                            .font(.caption2.bold())
                            .tracking(1.4)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .foregroundStyle(ADGTheme.paper)
                            .background(.red)
                            .clipShape(Capsule())
                    }
                    Text(event.title)
                        .font(.title.bold())
                    Text(event.startsAt, format: .dateTime.day().month().hour().minute())
                        .font(.caption.weight(.medium))
                        .tracking(1.1)
                        .textCase(.uppercase)
                }

                Spacer()

                if isAdmin {
                    HStack {
                        Button(action: onRoster) { Image(systemName: "list.bullet.clipboard") }
                        Button(action: onEdit) { Image(systemName: "pencil") }
                        Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
                    }
                }
            }

            Text(event.summary)
                .lineSpacing(4)

            HStack {
                Text(event.venue)
                Spacer()
                Text(event.registrationEnabled ? "Registration open" : "Registration closed")
                    .fontWeight(.semibold)
            }
            .font(.caption)

            Button(action: onRegister) {
                Text(registerButtonTitle)
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .foregroundStyle(ADGTheme.paper)
                    .background(buttonBackground)
            }
            .disabled(!event.isRegistrationOpen || isRegistered)
        }
        .padding(16)
        .background(ADGTheme.surface)
    }

    private var registerButtonTitle: String {
        if isRegistered { return "Registered" }
        return event.registrationEnabled ? "Register Now" : "Registration Closed"
    }

    private var buttonBackground: Color {
        if isRegistered { return .green }
        return event.isRegistrationOpen ? ADGTheme.ink : .gray
    }
}

private struct NoUpcomingEventsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Text("🎉")
                .font(.system(size: 60))
                .phaseAnimator([false, true]) { content, phase in
                    content
                        .scaleEffect(phase ? 1.1 : 1.0)
                        .rotationEffect(.degrees(phase ? 5 : -5))
                } animation: { phase in
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true)
                }
            
            VStack(spacing: 6) {
                Text("No upcoming events yet")
                    .font(.headline)
                    .foregroundStyle(ADGTheme.ink)
                
                Text("Check back later or explore our past events!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
}

private struct PastEventTile: View {
    var event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RemoteImageView(urlString: event.coverImageURL, aspectRatio: 3 / 4)
                .frame(minWidth: 0, maxWidth: .infinity)
                .aspectRatio(3 / 4, contentMode: .fit)
                .contentShape(Rectangle())
                .clipped()
                .cornerRadius(8)
            
            Text(event.title)
                .font(.headline)
                .lineLimit(1)
            
            Text(event.startsAt, style: .date)
                .font(.caption)
                .tracking(0.8)
                .foregroundStyle(.secondary)
        }
        .padding(8)
    }
}

private struct PastEventDetailPanel: View {
    var event: Event
    var isAdmin: Bool
    var onRoster: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let urlString = event.coverImageURL {
                        RemoteImageView(urlString: urlString, aspectRatio: 3 / 4)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(3 / 4, contentMode: .fit)
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(event.title)
                            .font(.title2.bold())
                            .foregroundStyle(ADGTheme.ink)
                        
                        HStack(spacing: 12) {
                            Label(event.startsAt.formatted(date: .long, time: .shortened), systemImage: "calendar")
                            Label(event.venue, systemImage: "mappin.and.ellipse")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Event Overview")
                            .font(.headline)
                            .foregroundStyle(ADGTheme.ink)
                        
                        Text(event.summary)
                            .font(.body)
                            .lineSpacing(6)
                            .foregroundStyle(ADGTheme.ink.opacity(0.8))
                    }

                    if isAdmin {
                        Button {
                            dismiss()
                            onRoster()
                        } label: {
                            Label("View Roster", systemImage: "list.bullet.clipboard")
                                .font(.caption.weight(.bold))
                                .tracking(1)
                                .textCase(.uppercase)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .foregroundStyle(ADGTheme.paper)
                                .background(ADGTheme.ink)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Past Event Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct EventEditor: View {
    @Bindable var viewModel: EventsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Title", text: $viewModel.draft.title)
                    TextField("Summary", text: $viewModel.draft.summary, axis: .vertical)
                    TextField("Venue", text: $viewModel.draft.venue)
                    DatePicker("Starts", selection: $viewModel.draft.startsAt)
                }
                
                Section("Poster") {
                    PhotosPicker(selection: $viewModel.selectedPhoto, matching: .images) {
                        Label("Choose Event Poster", systemImage: "photo")
                    }

                    if let coverImageURL = viewModel.draft.coverImageURL {
                        Text(coverImageURL)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Section("Registration") {
                    Toggle("Registration Enabled", isOn: $viewModel.draft.registrationEnabled)
                    
                    Picker("Method", selection: $viewModel.draft.registrationMethod) {
                        ForEach(RegistrationMethod.allCases) { method in
                            Text(method.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                .tag(method)
                        }
                    }
                    TextField("External URL", text: Binding(
                        get: { viewModel.draft.registrationURL ?? "" },
                        set: { viewModel.draft.registrationURL = $0.isEmpty ? nil : $0 }
                    ))

                    Toggle("Require Phone", isOn: $viewModel.draft.requiredFields.phone)
                    Toggle("Require Registration Number", isOn: $viewModel.draft.requiredFields.registrationNumber)
                    Toggle("Require Department", isOn: $viewModel.draft.requiredFields.department)
                    Toggle("Require Year", isOn: $viewModel.draft.requiredFields.year)
                    Toggle("Show Notes", isOn: $viewModel.draft.requiredFields.notes)
                }
            }
            .navigationTitle("Event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.saveDraft()
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
