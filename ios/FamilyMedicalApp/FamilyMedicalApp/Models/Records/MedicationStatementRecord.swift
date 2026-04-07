import Foundation

struct MedicationStatementRecord: MedicalRecordContent {
    static let recordType: RecordType = .medicationStatement
    static let schemaVersion: Int = 1
    static let displayName: String = "Medication"
    static let iconSystemName: String = "pills"

    // Type-specific fields
    var medicationName: String
    var dosage: String?
    var frequency: String?
    var startDate: Date?
    var endDate: Date?
    var reasonForUse: String?
    var pharmacyId: UUID?
    var providerId: UUID?

    // Common fields
    var notes: String?
    var tags: [String]
    var unknownFields: [String: JSONValue]

    init(
        medicationName: String,
        dosage: String? = nil,
        frequency: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        reasonForUse: String? = nil,
        pharmacyId: UUID? = nil,
        providerId: UUID? = nil,
        notes: String? = nil,
        tags: [String] = [],
        unknownFields: [String: JSONValue] = [:]
    ) {
        self.medicationName = medicationName
        self.dosage = dosage
        self.frequency = frequency
        self.startDate = startDate
        self.endDate = endDate
        self.reasonForUse = reasonForUse
        self.pharmacyId = pharmacyId
        self.providerId = providerId
        self.notes = notes
        self.tags = tags
        self.unknownFields = unknownFields
    }

    // MARK: - Known coding keys

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case medicationName, dosage, frequency, startDate, endDate
        case reasonForUse, pharmacyId, providerId
        case notes, tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        medicationName = try container.decode(String.self, forKey: .medicationName)
        dosage = try container.decodeIfPresent(String.self, forKey: .dosage)
        frequency = try container.decodeIfPresent(String.self, forKey: .frequency)
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        reasonForUse = try container.decodeIfPresent(String.self, forKey: .reasonForUse)
        pharmacyId = try container.decodeIfPresent(UUID.self, forKey: .pharmacyId)
        providerId = try container.decodeIfPresent(UUID.self, forKey: .providerId)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []

        unknownFields = try Self.captureUnknownFields(
            from: decoder,
            knownKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(medicationName, forKey: .medicationName)
        try container.encodeIfPresent(dosage, forKey: .dosage)
        try container.encodeIfPresent(frequency, forKey: .frequency)
        try container.encodeIfPresent(startDate, forKey: .startDate)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encodeIfPresent(reasonForUse, forKey: .reasonForUse)
        try container.encodeIfPresent(pharmacyId, forKey: .pharmacyId)
        try container.encodeIfPresent(providerId, forKey: .providerId)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(tags, forKey: .tags)

        try emitUnknownFields(to: encoder)
    }

    // MARK: - Field metadata for form rendering

    static let fieldMetadata: [FieldMetadata] = [
        FieldMetadata(
            keyPath: "medicationName",
            displayName: "Medication Name",
            fieldType: .autocomplete,
            isRequired: true,
            placeholder: "e.g., Amoxicillin",
            autocompleteSource: .whoMedications,
            displayOrder: 1
        ),
        FieldMetadata(
            keyPath: "dosage",
            displayName: "Dosage",
            fieldType: .text,
            placeholder: "e.g., 500mg",
            displayOrder: 2
        ),
        FieldMetadata(
            keyPath: "frequency",
            displayName: "Frequency",
            fieldType: .picker,
            pickerOptions: [
                "Once daily",
                "Twice daily",
                "Three times daily",
                "Every 8 hours",
                "Every 12 hours",
                "Weekly",
                "As needed (PRN)",
                "Other"
            ],
            displayOrder: 3
        ),
        FieldMetadata(keyPath: "startDate", displayName: "Start Date", fieldType: .date, displayOrder: 4),
        FieldMetadata(keyPath: "endDate", displayName: "End Date", fieldType: .date, displayOrder: 5),
        FieldMetadata(keyPath: "reasonForUse", displayName: "Reason for Use", fieldType: .text, displayOrder: 6),
        // NOTE: pharmacyId has no `.entityReference(.pharmacy)` semantic because no
        // Pharmacy model/repository/resolver exists yet. With the semantic set the
        // field was unusable (no suggestions, cleared stored UUID on any typing).
        // Leaving it as a plain autocomplete means it behaves as free-text with no
        // suggestions until Pharmacy infrastructure lands. The `.pharmacy` enum case
        // is retained in EntityKind as a breadcrumb for the follow-up.
        FieldMetadata(
            keyPath: "pharmacyId",
            displayName: "Pharmacy",
            fieldType: .autocomplete,
            displayOrder: 7
        ),
        FieldMetadata(
            keyPath: "providerId",
            displayName: "Provider",
            fieldType: .autocomplete,
            displayOrder: 8,
            semantic: .entityReference(.provider)
        ),
        FieldMetadata(keyPath: "notes", displayName: "Notes", fieldType: .multilineText, displayOrder: 100),
        FieldMetadata(keyPath: "tags", displayName: "Tags", fieldType: .text, displayOrder: 101, semantic: .tagList)
    ]
}
