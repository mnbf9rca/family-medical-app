import SwiftUI

/// Row view displaying a person in the members list
struct PersonRowView: View {
    let person: Person

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(person.name)
                .font(.headline)

            if !person.labels.isEmpty {
                Text(person.labels.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let dob = person.dateOfBirth {
                Text(dob, format: .dateTime.month().day().year())
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var description = person.name

        if !person.labels.isEmpty {
            description += ", \(person.labels.joined(separator: ", "))"
        }

        if let dob = person.dateOfBirth {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            description += ", born \(formatter.string(from: dob))"
        }

        return description
    }
}

#Preview("Single Person") {
    if let person = try? Person(
        id: UUID(),
        name: "Alice Smith",
        dateOfBirth: Date(timeIntervalSince1970: 631_152_000), // Jan 1, 1990
        labels: ["Self"],
        notes: nil
    ) {
        List {
            PersonRowView(person: person)
        }
    }
}

#Preview("Person with Multiple Labels") {
    if let person = try? Person(
        id: UUID(),
        name: "Bob Johnson",
        dateOfBirth: Date(timeIntervalSince1970: 946_684_800), // Jan 1, 2000
        labels: ["Child", "Dependent"],
        notes: nil
    ) {
        List {
            PersonRowView(person: person)
        }
    }
}

#Preview("Person without DOB") {
    if let person = try? Person(
        id: UUID(),
        name: "Carol Williams",
        dateOfBirth: nil,
        labels: ["Spouse"],
        notes: nil
    ) {
        List {
            PersonRowView(person: person)
        }
    }
}
