import Foundation
import Testing
@testable import FamilyMedicalApp

struct PersonTests {
    // MARK: - Valid Initialization

    @Test
    func init_validPerson_succeeds() throws {
        let person = try Person(
            name: "John Doe",
            dateOfBirth: Date(timeIntervalSince1970: 0),
            labels: ["child", "dependent"]
        )

        #expect(person.name == "John Doe")
        #expect(person.dateOfBirth != nil)
        #expect(person.labels == ["child", "dependent"])
    }

    @Test
    func init_minimalPerson_succeeds() throws {
        let person = try Person(name: "A") // Minimum length name
        #expect(person.name == "A")
        #expect(person.labels.isEmpty)
        #expect(person.dateOfBirth == nil)
    }

    // MARK: - Name Validation

    @Test
    func init_emptyName_throwsError() {
        #expect(throws: ModelError.self) {
            _ = try Person(name: "")
        }
    }

    @Test
    func init_whitespaceName_throwsError() {
        #expect(throws: ModelError.self) {
            _ = try Person(name: "   ")
        }
    }

    @Test
    func init_nameTooLong_throwsError() {
        let longName = String(repeating: "a", count: Person.nameMaxLength + 1)
        #expect(throws: ModelError.self) {
            _ = try Person(name: longName)
        }
    }

    @Test
    func init_nameMaxLength_succeeds() throws {
        let maxName = String(repeating: "a", count: Person.nameMaxLength)
        let person = try Person(name: maxName)
        #expect(person.name.count == Person.nameMaxLength)
    }

    @Test
    func init_nameTrimsWhitespace() throws {
        let person = try Person(name: "  John Doe  ")
        #expect(person.name == "John Doe")
    }

    // MARK: - Label Validation

    @Test
    func init_emptyLabel_throwsError() {
        #expect(throws: ModelError.self) {
            _ = try Person(name: "John", labels: [""])
        }
    }

    @Test
    func init_whitespaceLabel_throwsError() {
        #expect(throws: ModelError.self) {
            _ = try Person(name: "John", labels: ["   "])
        }
    }

    @Test
    func init_labelTooLong_throwsError() {
        let longLabel = String(repeating: "a", count: Person.labelMaxLength + 1)
        #expect(throws: ModelError.self) {
            _ = try Person(name: "John", labels: [longLabel])
        }
    }

    @Test
    func init_labelsTrimsWhitespace() throws {
        let person = try Person(name: "John", labels: ["  child  ", "  dependent  "])
        #expect(person.labels == ["child", "dependent"])
    }

    // MARK: - Label Helpers

    @Test
    func hasLabel_existingLabel_returnsTrue() throws {
        let person = try Person(name: "John", labels: ["child", "dependent"])
        #expect(person.hasLabel("child"))
        #expect(person.hasLabel("dependent"))
    }

    @Test
    func hasLabel_nonExistentLabel_returnsFalse() throws {
        let person = try Person(name: "John", labels: ["child"])
        #expect(!person.hasLabel("parent"))
    }

    @Test
    func hasLabel_caseInsensitive() throws {
        let person = try Person(name: "John", labels: ["Child"])
        #expect(person.hasLabel("child"))
        #expect(person.hasLabel("CHILD"))
        #expect(person.hasLabel("Child"))
    }

    @Test
    func addLabel_newLabel_adds() throws {
        var person = try Person(name: "John", labels: ["child"])
        try person.addLabel("dependent")
        #expect(person.labels.count == 2)
        #expect(person.hasLabel("dependent"))
    }

    @Test
    func addLabel_duplicateLabel_doesNotAdd() throws {
        var person = try Person(name: "John", labels: ["child"])
        try person.addLabel("child")
        #expect(person.labels.count == 1)
    }

    @Test
    func addLabel_emptyLabel_throwsError() throws {
        var person = try Person(name: "John")
        #expect(throws: ModelError.self) {
            try person.addLabel("")
        }
    }

    @Test
    func removeLabel_existingLabel_removes() throws {
        var person = try Person(name: "John", labels: ["child", "dependent"])
        person.removeLabel("child")
        #expect(person.labels == ["dependent"])
    }

    @Test
    func removeLabel_nonExistentLabel_doesNothing() throws {
        var person = try Person(name: "John", labels: ["child"])
        person.removeLabel("parent")
        #expect(person.labels == ["child"])
    }

    @Test
    func removeLabel_caseInsensitive() throws {
        var person = try Person(name: "John", labels: ["Child"])
        person.removeLabel("child")
        #expect(person.labels.isEmpty)
    }

    // MARK: - Codable

    @Test
    func codable_roundTrip() throws {
        let original = try Person(
            id: UUID(),
            name: "John Doe",
            dateOfBirth: Date(timeIntervalSince1970: 1_000_000),
            labels: ["child", "dependent"],
            notes: "Some notes"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Person.self, from: encoded)

        #expect(decoded == original)
        #expect(decoded.name == original.name)
        #expect(decoded.labels == original.labels)
    }

    // MARK: - Equatable

    @Test
    func equatable_samePerson_equal() throws {
        let id = UUID()
        let now = Date()
        let person1 = try Person(id: id, name: "John", labels: ["child"], createdAt: now, updatedAt: now)
        let person2 = try Person(id: id, name: "John", labels: ["child"], createdAt: now, updatedAt: now)
        #expect(person1 == person2)
    }

    @Test
    func equatable_differentPerson_notEqual() throws {
        let person1 = try Person(name: "John")
        let person2 = try Person(name: "Jane")
        #expect(person1 != person2)
    }

    // MARK: - Common Labels

    @Test
    func commonLabels_providesDefaults() {
        #expect(!Person.commonLabels.isEmpty)
        #expect(Person.commonLabels.contains("Self"))
        #expect(Person.commonLabels.contains("Child"))
        #expect(Person.commonLabels.contains("Parent"))
    }
}
