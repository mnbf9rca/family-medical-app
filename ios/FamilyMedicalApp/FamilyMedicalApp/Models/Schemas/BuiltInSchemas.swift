import Foundation

/// Provides built-in schema definitions for common medical record types
enum BuiltInSchemas {
    // MARK: - Schema Factory

    /// Get a built-in schema by type
    ///
    /// - Parameter type: The built-in schema type
    /// - Returns: The corresponding schema
    static func schema(for type: BuiltInSchemaType) -> RecordSchema {
        switch type {
        case .vaccine:
            vaccineSchema
        case .condition:
            conditionSchema
        case .medication:
            medicationSchema
        case .allergy:
            allergySchema
        case .note:
            noteSchema
        }
    }
}

// MARK: - Vaccine Schema Extension

extension BuiltInSchemas {
    // MARK: - Vaccine Schema

    private static var vaccineSchema: RecordSchema {
        RecordSchema(
            unsafeId: "vaccine",
            displayName: "Vaccine",
            iconSystemName: "syringe",
            fields: [
                FieldDefinition(
                    id: "vaccineName",
                    displayName: "Vaccine Name",
                    fieldType: .string,
                    isRequired: true,
                    displayOrder: 1,
                    placeholder: "e.g., COVID-19, MMR, Flu",
                    helpText: "Name of the vaccine administered",
                    validationRules: [.minLength(1), .maxLength(200)]
                ),
                FieldDefinition(
                    id: "dateAdministered",
                    displayName: "Date Administered",
                    fieldType: .date,
                    isRequired: true,
                    displayOrder: 2,
                    helpText: "Date when the vaccine was given"
                ),
                FieldDefinition(
                    id: "provider",
                    displayName: "Healthcare Provider",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 3,
                    placeholder: "e.g., Dr. Smith, CVS Pharmacy",
                    helpText: "Provider or location where vaccine was administered",
                    validationRules: [.maxLength(200)]
                ),
                FieldDefinition(
                    id: "batchNumber",
                    displayName: "Batch/Lot Number",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 4,
                    placeholder: "e.g., 123ABC",
                    helpText: "Batch or lot number from the vaccine vial",
                    validationRules: [.maxLength(50)]
                ),
                FieldDefinition(
                    id: "doseNumber",
                    displayName: "Dose Number",
                    fieldType: .int,
                    isRequired: false,
                    displayOrder: 5,
                    placeholder: "e.g., 1, 2, 3",
                    helpText: "Which dose in the series (1st, 2nd, booster, etc.)",
                    validationRules: [.minValue(1)]
                ),
                FieldDefinition(
                    id: "expirationDate",
                    displayName: "Expiration Date",
                    fieldType: .date,
                    isRequired: false,
                    displayOrder: 6,
                    helpText: "Expiration date of the vaccine batch"
                ),
                FieldDefinition(
                    id: "notes",
                    displayName: "Notes",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 7,
                    placeholder: "Any additional notes",
                    helpText: "Additional information or reactions",
                    validationRules: [.maxLength(2_000)]
                ),
                FieldDefinition(
                    id: "attachmentIds",
                    displayName: "Attachments",
                    fieldType: .attachmentIds,
                    isRequired: false,
                    displayOrder: 8,
                    helpText: "Photos of vaccine card, documentation, etc."
                )
            ],
            isBuiltIn: true,
            description: "Record of vaccinations received"
        )
    }
}

// MARK: - Condition Schema Extension

extension BuiltInSchemas {
    private static var conditionSchema: RecordSchema {
        RecordSchema(
            unsafeId: "condition",
            displayName: "Medical Condition",
            iconSystemName: "heart.text.square",
            fields: [
                FieldDefinition(
                    id: "conditionName",
                    displayName: "Condition Name",
                    fieldType: .string,
                    isRequired: true,
                    displayOrder: 1,
                    placeholder: "e.g., Asthma, Diabetes, Hypertension",
                    helpText: "Name of the medical condition",
                    validationRules: [.minLength(1), .maxLength(200)]
                ),
                FieldDefinition(
                    id: "diagnosedDate",
                    displayName: "Date Diagnosed",
                    fieldType: .date,
                    isRequired: false,
                    displayOrder: 2,
                    helpText: "When the condition was diagnosed"
                ),
                FieldDefinition(
                    id: "status",
                    displayName: "Status",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 3,
                    placeholder: "e.g., Active, Resolved, Chronic, In Remission",
                    helpText: "Current status of the condition",
                    validationRules: [.maxLength(50)]
                ),
                FieldDefinition(
                    id: "severity",
                    displayName: "Severity",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 4,
                    placeholder: "e.g., Mild, Moderate, Severe",
                    helpText: "Severity of the condition",
                    validationRules: [.maxLength(50)]
                ),
                FieldDefinition(
                    id: "treatedBy",
                    displayName: "Treated By",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 5,
                    placeholder: "e.g., Dr. Johnson",
                    helpText: "Healthcare provider managing this condition",
                    validationRules: [.maxLength(200)]
                ),
                FieldDefinition(
                    id: "notes",
                    displayName: "Notes",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 6,
                    placeholder: "Any additional notes",
                    helpText: "Additional information about the condition",
                    validationRules: [.maxLength(2_000)]
                ),
                FieldDefinition(
                    id: "attachmentIds",
                    displayName: "Attachments",
                    fieldType: .attachmentIds,
                    isRequired: false,
                    displayOrder: 7,
                    helpText: "Medical records, test results, etc."
                )
            ],
            isBuiltIn: true,
            description: "Ongoing or past medical conditions"
        )
    }
}

// MARK: - Medication Schema Extension

extension BuiltInSchemas {
    private static var medicationSchema: RecordSchema {
        RecordSchema(
            unsafeId: "medication",
            displayName: "Medication",
            iconSystemName: "pills",
            fields: [
                FieldDefinition(
                    id: "medicationName",
                    displayName: "Medication Name",
                    fieldType: .string,
                    isRequired: true,
                    displayOrder: 1,
                    placeholder: "e.g., Aspirin, Metformin",
                    helpText: "Name of the medication",
                    validationRules: [.minLength(1), .maxLength(200)]
                ),
                FieldDefinition(
                    id: "dosage",
                    displayName: "Dosage",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 2,
                    placeholder: "e.g., 500mg, 10mL",
                    helpText: "Dosage amount",
                    validationRules: [.maxLength(100)]
                ),
                FieldDefinition(
                    id: "frequency",
                    displayName: "Frequency",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 3,
                    placeholder: "e.g., Twice daily, As needed",
                    helpText: "How often to take",
                    validationRules: [.maxLength(100)]
                ),
                FieldDefinition(
                    id: "startDate",
                    displayName: "Start Date",
                    fieldType: .date,
                    isRequired: false,
                    displayOrder: 4,
                    helpText: "When this medication was started"
                ),
                FieldDefinition(
                    id: "endDate",
                    displayName: "End Date",
                    fieldType: .date,
                    isRequired: false,
                    displayOrder: 5,
                    helpText: "When this medication was stopped (if applicable)"
                ),
                FieldDefinition(
                    id: "prescribedBy",
                    displayName: "Prescribed By",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 6,
                    placeholder: "e.g., Dr. Williams",
                    helpText: "Healthcare provider who prescribed this medication",
                    validationRules: [.maxLength(200)]
                ),
                FieldDefinition(
                    id: "pharmacy",
                    displayName: "Pharmacy",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 7,
                    placeholder: "e.g., Walgreens",
                    helpText: "Pharmacy where prescription is filled",
                    validationRules: [.maxLength(200)]
                ),
                FieldDefinition(
                    id: "refillsRemaining",
                    displayName: "Refills Remaining",
                    fieldType: .int,
                    isRequired: false,
                    displayOrder: 8,
                    placeholder: "e.g., 3",
                    helpText: "Number of refills remaining",
                    validationRules: [.minValue(0)]
                ),
                FieldDefinition(
                    id: "notes",
                    displayName: "Notes",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 9,
                    placeholder: "Any additional notes",
                    helpText: "Additional information or side effects",
                    validationRules: [.maxLength(2_000)]
                ),
                FieldDefinition(
                    id: "attachmentIds",
                    displayName: "Attachments",
                    fieldType: .attachmentIds,
                    isRequired: false,
                    displayOrder: 10,
                    helpText: "Prescription labels, instructions, etc."
                )
            ],
            isBuiltIn: true,
            description: "Current and past medications"
        )
    }
}

// MARK: - Allergy Schema Extension

extension BuiltInSchemas {
    private static var allergySchema: RecordSchema {
        RecordSchema(
            unsafeId: "allergy",
            displayName: "Allergy",
            iconSystemName: "exclamationmark.triangle",
            fields: [
                FieldDefinition(
                    id: "allergen",
                    displayName: "Allergen",
                    fieldType: .string,
                    isRequired: true,
                    displayOrder: 1,
                    placeholder: "e.g., Peanuts, Penicillin, Pollen",
                    helpText: "What causes the allergic reaction",
                    validationRules: [.minLength(1), .maxLength(200)]
                ),
                FieldDefinition(
                    id: "severity",
                    displayName: "Severity",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 2,
                    placeholder: "e.g., Mild, Moderate, Severe, Life-threatening",
                    helpText: "Severity of the allergic reaction",
                    validationRules: [.maxLength(50)]
                ),
                FieldDefinition(
                    id: "reaction",
                    displayName: "Reaction",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 3,
                    placeholder: "e.g., Hives, Swelling, Anaphylaxis",
                    helpText: "Type of allergic reaction",
                    validationRules: [.maxLength(200)]
                ),
                FieldDefinition(
                    id: "diagnosedDate",
                    displayName: "Date Diagnosed",
                    fieldType: .date,
                    isRequired: false,
                    displayOrder: 4,
                    helpText: "When the allergy was diagnosed"
                ),
                FieldDefinition(
                    id: "notes",
                    displayName: "Notes",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 5,
                    placeholder: "Any additional notes",
                    helpText: "Additional information or treatment details",
                    validationRules: [.maxLength(2_000)]
                ),
                FieldDefinition(
                    id: "attachmentIds",
                    displayName: "Attachments",
                    fieldType: .attachmentIds,
                    isRequired: false,
                    displayOrder: 6,
                    helpText: "Allergy test results, medical alert bracelet photos, etc."
                )
            ],
            isBuiltIn: true,
            description: "Allergies and sensitivities"
        )
    }
}

// MARK: - Note Schema Extension

extension BuiltInSchemas {
    private static var noteSchema: RecordSchema {
        RecordSchema(
            unsafeId: "note",
            displayName: "Note",
            iconSystemName: "note.text",
            fields: [
                FieldDefinition(
                    id: "title",
                    displayName: "Title",
                    fieldType: .string,
                    isRequired: true,
                    displayOrder: 1,
                    placeholder: "e.g., Doctor Visit, Lab Results",
                    helpText: "Brief title for this note",
                    validationRules: [.minLength(1), .maxLength(200)]
                ),
                FieldDefinition(
                    id: "content",
                    displayName: "Content",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 2,
                    placeholder: "Notes and details",
                    helpText: "Full content of the note",
                    validationRules: [.maxLength(10_000)]
                ),
                FieldDefinition(
                    id: "attachmentIds",
                    displayName: "Attachments",
                    fieldType: .attachmentIds,
                    isRequired: false,
                    displayOrder: 3,
                    helpText: "Related documents, images, etc."
                )
            ],
            isBuiltIn: true,
            description: "Generic notes for any health information"
        )
    }
}
