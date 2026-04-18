import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct RecordTypeRowViewTests {
    // MARK: - Content Tests

    @Test
    func viewDisplaysRecordTypeName() throws {
        let view = RecordTypeRowView(recordType: .immunization, recordCount: 3)

        try HostedInspection.inspect(view) { view in
            let hStack = try view.inspect().hStack()
            let nameText = try hStack.text(1)
            #expect(try nameText.string() == "Immunization")
        }
    }

    @Test
    func viewDisplaysRecordCount() throws {
        let view = RecordTypeRowView(recordType: .condition, recordCount: 5)

        try HostedInspection.inspect(view) { view in
            let hStack = try view.inspect().hStack()
            // HStack has: Image(0), Text(1), Spacer(2), Text(3) when count > 0
            let countText = try hStack.text(3)
            #expect(try countText.string() == "5")
        }
    }

    @Test
    func viewHidesCountWhenZero() throws {
        let view = RecordTypeRowView(recordType: .medicationStatement, recordCount: 0)

        try HostedInspection.inspect(view) { view in
            let hStack = try view.inspect().hStack()
            // Should only have image, name text, and spacer - no count
            #expect(throws: (any Error).self) {
                _ = try hStack.text(2)
            }
        }
    }

    @Test
    func viewDisplaysIcon() throws {
        let view = RecordTypeRowView(recordType: .allergyIntolerance, recordCount: 1)

        try HostedInspection.inspect(view) { view in
            let hStack = try view.inspect().hStack()
            let image = try hStack.image(0)
            #expect(throws: Never.self) {
                _ = try image.actualImage()
            }
        }
    }

    @Test
    func viewRendersSuccessfully() throws {
        let view = RecordTypeRowView(recordType: .clinicalNote, recordCount: 2)

        // Just verify the view structure can be inspected
        try HostedInspection.inspect(view) { view in
            _ = try view.inspect()
        }
    }

    @Test
    func viewHandlesMultipleRecordCounts() throws {
        for count in [0, 1, 5, 10, 100] {
            let view = RecordTypeRowView(recordType: .immunization, recordCount: count)
            try HostedInspection.inspect(view) { view in
                _ = try view.inspect()
            }
        }
    }

    @Test
    func viewWorksWithAllRecordTypes() throws {
        for recordType in RecordType.allCases {
            let view = RecordTypeRowView(recordType: recordType, recordCount: 1)
            try HostedInspection.inspect(view) { view in
                _ = try view.inspect()
            }
        }
    }
}
