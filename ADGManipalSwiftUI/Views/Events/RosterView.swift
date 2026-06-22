import SwiftUI

struct RosterView: View {
    var event: Event?
    var registrations: [Registration]

    var body: some View {
        NavigationStack {
            List(registrations) { registration in
                VStack(alignment: .leading, spacing: 6) {
                    Text(registration.studentName)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(registration.email)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(registration.customInputs.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack {
                            Text(key.replacingOccurrences(of: "_", with: " ").capitalized)
                            Spacer()
                            Text(value)
                                .fontWeight(.semibold)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.caption)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.vertical, 6)
                .accessibilityElement(children: .combine)
            }
            .navigationTitle(event?.title ?? "Roster")
        }
    }
}
