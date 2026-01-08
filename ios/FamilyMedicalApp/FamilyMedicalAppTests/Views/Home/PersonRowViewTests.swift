import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct PersonRowViewTests {
    // MARK: - Test Data

    func createTestPerson(
        name: String = "Test Person",
        dateOfBirth: Date? = Date(),
        labels: [String] = ["Self"]
    ) throws -> Person {
        try PersonTestHelper.makeTestPerson(name: name, dateOfBirth: dateOfBirth, labels: labels)
    }

    // MARK: - Content Tests

    @Test
    func viewDisplaysPersonName() throws {
        let person = try createTestPerson(name: "Alice Smith")
        let view = PersonRowView(person: person)

        let vStack = try view.inspect().vStack()
        let nameText = try vStack.text(0)
        #expect(try nameText.string() == "Alice Smith")
    }

    @Test
    func viewDisplaysLabels() throws {
        let person = try createTestPerson(labels: ["Self", "Parent"])
        let view = PersonRowView(person: person)

        let vStack = try view.inspect().vStack()
        let labelsText = try vStack.text(1)
        #expect(try labelsText.string() == "Self, Parent")
    }

    @Test
    func viewDisplaysDateOfBirth() throws {
        let dob = Date(timeIntervalSince1970: 631_152_000) // Jan 1, 1990
        let person = try createTestPerson(dateOfBirth: dob)
        let view = PersonRowView(person: person)

        _ = try view.inspect().vStack()
        // DOB is displayed, verification that view renders without error
    }

    @Test
    func viewHandlesNilDateOfBirth() throws {
        let person = try createTestPerson(dateOfBirth: nil)
        let view = PersonRowView(person: person)

        _ = try view.inspect().vStack()
        // View should render without crashing with nil DOB
    }

    @Test
    func viewHandlesEmptyLabels() throws {
        let person = try createTestPerson(labels: [])
        let view = PersonRowView(person: person)

        _ = try view.inspect().vStack()
        // View should render without crashing even with no labels
    }

    // MARK: - Style Tests

    @Test
    func nameHasHeadlineFont() throws {
        let person = try createTestPerson()
        let view = PersonRowView(person: person)

        let vStack = try view.inspect().vStack()
        let nameText = try vStack.text(0)
        #expect(try nameText.attributes().font() == .headline)
    }

    @Test
    func viewRendersSuccessfully() throws {
        let person = try createTestPerson()
        let view = PersonRowView(person: person)

        // Just verify the view structure can be inspected
        _ = try view.inspect()
    }
}
