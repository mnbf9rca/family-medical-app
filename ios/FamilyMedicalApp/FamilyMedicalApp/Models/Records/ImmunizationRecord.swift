import Foundation

struct ImmunizationRecord: MedicalRecordContent {
    static let recordType: RecordType = .immunization
    static let schemaVersion: Int = 1
    static let displayName: String = "Immunization"
    static let iconSystemName: String = "syringe"

    // Type-specific fields
    var vaccineCode: String
    var occurrenceDate: Date
    var lotNumber: String?
    var site: String?
    var doseNumber: Int?
    var dosesInSeries: Int?
    var expirationDate: Date?
    var providerId: UUID?

    // Common fields
    var notes: String?
    var tags: [String]
    var unknownFields: [String: JSONValue]

    init(
        vaccineCode: String,
        occurrenceDate: Date,
        lotNumber: String? = nil,
        site: String? = nil,
        doseNumber: Int? = nil,
        dosesInSeries: Int? = nil,
        expirationDate: Date? = nil,
        providerId: UUID? = nil,
        notes: String? = nil,
        tags: [String] = [],
        unknownFields: [String: JSONValue] = [:]
    ) {
        self.vaccineCode = vaccineCode
        self.occurrenceDate = occurrenceDate
        self.lotNumber = lotNumber
        self.site = site
        self.doseNumber = doseNumber
        self.dosesInSeries = dosesInSeries
        self.expirationDate = expirationDate
        self.providerId = providerId
        self.notes = notes
        self.tags = tags
        self.unknownFields = unknownFields
    }

    // MARK: - Known coding keys

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case vaccineCode, occurrenceDate, lotNumber, site
        case doseNumber, dosesInSeries, expirationDate, providerId
        case notes, tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        vaccineCode = try container.decode(String.self, forKey: .vaccineCode)
        occurrenceDate = try container.decode(Date.self, forKey: .occurrenceDate)
        lotNumber = try container.decodeIfPresent(String.self, forKey: .lotNumber)
        site = try container.decodeIfPresent(String.self, forKey: .site)
        doseNumber = try container.decodeIfPresent(Int.self, forKey: .doseNumber)
        dosesInSeries = try container.decodeIfPresent(Int.self, forKey: .dosesInSeries)
        expirationDate = try container.decodeIfPresent(Date.self, forKey: .expirationDate)
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
        try container.encode(vaccineCode, forKey: .vaccineCode)
        try container.encode(occurrenceDate, forKey: .occurrenceDate)
        try container.encodeIfPresent(lotNumber, forKey: .lotNumber)
        try container.encodeIfPresent(site, forKey: .site)
        try container.encodeIfPresent(doseNumber, forKey: .doseNumber)
        try container.encodeIfPresent(dosesInSeries, forKey: .dosesInSeries)
        try container.encodeIfPresent(expirationDate, forKey: .expirationDate)
        try container.encodeIfPresent(providerId, forKey: .providerId)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(tags, forKey: .tags)

        try emitUnknownFields(to: encoder)
    }

    // MARK: - Field metadata for form rendering

    static let fieldMetadata: [FieldMetadata] = [
        FieldMetadata(
            keyPath: "vaccineCode",
            displayName: "Vaccine Name",
            fieldType: .autocomplete,
            isRequired: true,
            placeholder: "e.g., Pfizer-BioNTech COVID-19",
            autocompleteSource: .cvxVaccines,
            displayOrder: 1
        ),
        FieldMetadata(
            keyPath: "occurrenceDate",
            displayName: "Date Administered",
            fieldType: .date,
            isRequired: true,
            displayOrder: 2
        ),
        FieldMetadata(
            keyPath: "lotNumber",
            displayName: "Lot Number",
            fieldType: .text,
            placeholder: "e.g., EL9262",
            displayOrder: 3
        ),
        FieldMetadata(
            keyPath: "site",
            displayName: "Body Site",
            fieldType: .text,
            placeholder: "e.g., Left arm",
            displayOrder: 4
        ),
        FieldMetadata(
            keyPath: "doseNumber",
            displayName: "Dose Number",
            fieldType: .integer,
            placeholder: "e.g., 2",
            displayOrder: 5
        ),
        FieldMetadata(
            keyPath: "dosesInSeries",
            displayName: "Doses in Series",
            fieldType: .integer,
            placeholder: "e.g., 3",
            displayOrder: 6
        ),
        FieldMetadata(keyPath: "expirationDate", displayName: "Vaccine Expiration", fieldType: .date, displayOrder: 7),
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
