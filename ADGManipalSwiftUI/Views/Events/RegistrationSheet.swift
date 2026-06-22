import SwiftUI
import UIKit

struct RegistrationSheet: View {
    var event: Event
    var initialEmail: String
    var onSubmit: (String, String, [String: String]) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email: String
    @State private var inputs: [String: String] = [:]
    @State private var isSubmitting = false

    init(
        event: Event,
        initialEmail: String,
        onSubmit: @escaping (String, String, [String: String]) async -> Void
    ) {
        self.event = event
        self.initialEmail = initialEmail
        self.onSubmit = onSubmit
        _email = State(initialValue: initialEmail)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(event.title) {
                    TextField("Student Name", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(!initialEmail.isEmpty)
                }

                Section("Details") {
                    if event.requiredFields.phone {
                        customField("Phone", key: "phone", keyboard: .phonePad)
                    }
                    if event.requiredFields.registrationNumber {
                        customField("Registration Number", key: "registration_number", keyboard: .numberPad)
                    }
                    if event.requiredFields.department {
                        customField("Department", key: "department")
                    }
                    if event.requiredFields.year {
                        customField("Year", key: "year", keyboard: .numberPad)
                    }
                    if event.requiredFields.notes {
                        customField("Notes", key: "notes", axis: .vertical)
                    }
                }
            }
            .disabled(isSubmitting)
            .navigationTitle("Register")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: submitForm) {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Submit")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .disabled(!isValid || isSubmitting)
                    .accessibilityHint("Submits your registration for \(event.title).")
                }
            }
        }
    }

    // MARK: - Dynamic Validation Logic
    private var isValid: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        
        if event.requiredFields.phone && (inputs["phone"] ?? "").isEmpty { return false }
        if event.requiredFields.registrationNumber && (inputs["registration_number"] ?? "").isEmpty { return false }
        if event.requiredFields.department && (inputs["department"] ?? "").isEmpty { return false }
        if event.requiredFields.year && (inputs["year"] ?? "").isEmpty { return false }
        if event.requiredFields.notes && (inputs["notes"] ?? "").isEmpty { return false }
        
        return true
    }

    // MARK: - Action Methods
    private func submitForm() {
        Task {
            isSubmitting = true
            await onSubmit(name, email, inputs)
            isSubmitting = false
            UIAccessibility.post(notification: .announcement, argument: "Registration submitted for \(event.title).")
            dismiss()
        }
    }

    // MARK: - Helper Builder View
    @ViewBuilder
    private func customField(_ label: String, key: String, axis: Axis = .horizontal, keyboard: UIKeyboardType = .default) -> some View {
        TextField(label, text: Binding(
            get: { inputs[key] ?? "" },
            set: { inputs[key] = $0 }
        ), axis: axis)
        .keyboardType(keyboard)
    }
}
