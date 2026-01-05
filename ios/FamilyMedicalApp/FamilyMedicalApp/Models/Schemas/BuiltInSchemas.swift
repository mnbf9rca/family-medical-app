import Foundation

/// Provides built-in schema definitions for common medical record types
///
/// These schemas serve as templates that are seeded to each Person's schema set
/// when they are created. Built-in schemas use hardcoded UUIDs from `BuiltInFieldIds`
/// for stable field identification.
///
/// Per ADR-0009 (Schema Evolution in Multi-Master Replication):
/// - Built-in schemas are seeded per-Person at creation time
/// - Each Person gets their own copy of built-in schemas
/// - Users can customize their copy without affecting others
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
                .builtIn(
                    id: BuiltInFieldIds.Vaccine.name,
                    displayName: "Vaccine Name",
                    fieldType: .string,
                    isRequired: true,
                    displayOrder: 1,
                    placeholder: "e.g., COVID-19, MMR, Flu",
                    helpText: "Name of the vaccine administered",
                    validationRules: [.minLength(1), .maxLength(200)],
                    capitalizationMode: .words
                ),
                .builtIn(
                    id: BuiltInFieldIds.Vaccine.dateAdministered,
                    displayName: "Date Administered",
                    fieldType: .date,
                    isRequired: true,
                    displayOrder: 2,
                    helpText: "Date when the vaccine was given"
                ),
                .builtIn(
                    id: BuiltInFieldIds.Vaccine.provider,
                    displayName: "Healthcare Provider",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 3,
                    placeholder: "e.g., Dr. Smith, CVS Pharmacy",
                    helpText: "Provider or location where vaccine was administered",
                    validationRules: [.maxLength(200)],
                    capitalizationMode: .words
                ),
                .builtIn(
                    id: BuiltInFieldIds.Vaccine.batchNumber,
                    displayName: "Batch/Lot Number",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 4,
                    placeholder: "e.g., 123ABC",
                    helpText: "Batch or lot number from the vaccine vial",
                    validationRules: [.maxLength(50)]
                ),
                .builtIn(
                    id: BuiltInFieldIds.Vaccine.doseNumber,
                    displayName: "Dose Number",
                    fieldType: .int,
                    isRequired: false,
                    displayOrder: 5,
                    placeholder: "e.g., 1, 2, 3",
                    helpText: "Which dose in the series (1st, 2nd, booster, etc.)",
                    validationRules: [.minValue(1)]
                ),
                .builtIn(
                    id: BuiltInFieldIds.Vaccine.expirationDate,
                    displayName: "Expiration Date",
                    fieldType: .date,
                    isRequired: false,
                    displayOrder: 6,
                    helpText: "Expiration date of the vaccine batch"
                ),
                .builtIn(
                    id: BuiltInFieldIds.Vaccine.notes,
                    displayName: "Notes",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 7,
                    placeholder: "Any additional notes",
                    helpText: "Additional information or reactions",
                    validationRules: [.maxLength(2_000)],
                    isMultiline: true
                ),
                .builtIn(
                    id: BuiltInFieldIds.Vaccine.attachmentIds,
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
                .builtIn(
                    id: BuiltInFieldIds.Condition.name,
                    displayName: "Condition Name",
                    fieldType: .string,
                    isRequired: true,
                    displayOrder: 1,
                    placeholder: "e.g., Asthma, Diabetes, Hypertension",
                    helpText: "Name of the medical condition",
                    validationRules: [.minLength(1), .maxLength(200)],
                    capitalizationMode: .words
                ),
                .builtIn(
                    id: BuiltInFieldIds.Condition.diagnosedDate,
                    displayName: "Date Diagnosed",
                    fieldType: .date,
                    isRequired: false,
                    displayOrder: 2,
                    helpText: "When the condition was diagnosed"
                ),
                .builtIn(
                    id: BuiltInFieldIds.Condition.status,
                    displayName: "Status",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 3,
                    placeholder: "e.g., Active, Resolved, Chronic, In Remission",
                    helpText: "Current status of the condition",
                    validationRules: [.maxLength(50)]
                ),
                .builtIn(
                    id: BuiltInFieldIds.Condition.severity,
                    displayName: "Severity",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 4,
                    placeholder: "e.g., Mild, Moderate, Severe",
                    helpText: "Severity of the condition",
                    validationRules: [.maxLength(50)]
                ),
                .builtIn(
                    id: BuiltInFieldIds.Condition.treatedBy,
                    displayName: "Treated By",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 5,
                    placeholder: "e.g., Dr. Johnson",
                    helpText: "Healthcare provider managing this condition",
                    validationRules: [.maxLength(200)],
                    capitalizationMode: .words
                ),
                .builtIn(
                    id: BuiltInFieldIds.Condition.notes,
                    displayName: "Notes",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 6,
                    placeholder: "Any additional notes",
                    helpText: "Additional information about the condition",
                    validationRules: [.maxLength(2_000)],
                    isMultiline: true
                ),
                .builtIn(
                    id: BuiltInFieldIds.Condition.attachmentIds,
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
                .builtIn(
                    id: BuiltInFieldIds.Medication.name,
                    displayName: "Medication Name",
                    fieldType: .string,
                    isRequired: true,
                    displayOrder: 1,
                    placeholder: "e.g., Aspirin, Metformin",
                    helpText: "Name of the medication",
                    validationRules: [.minLength(1), .maxLength(200)],
                    capitalizationMode: .words
                ),
                .builtIn(
                    id: BuiltInFieldIds.Medication.dosage,
                    displayName: "Dosage",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 2,
                    placeholder: "e.g., 500mg, 10mL",
                    helpText: "Dosage amount",
                    validationRules: [.maxLength(100)]
                ),
                .builtIn(
                    id: BuiltInFieldIds.Medication.frequency,
                    displayName: "Frequency",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 3,
                    placeholder: "e.g., Twice daily, As needed",
                    helpText: "How often to take",
                    validationRules: [.maxLength(100)]
                ),
                .builtIn(
                    id: BuiltInFieldIds.Medication.startDate,
                    displayName: "Start Date",
                    fieldType: .date,
                    isRequired: false,
                    displayOrder: 4,
                    helpText: "When this medication was started"
                ),
                .builtIn(
                    id: BuiltInFieldIds.Medication.endDate,
                    displayName: "End Date",
                    fieldType: .date,
                    isRequired: false,
                    displayOrder: 5,
                    helpText: "When this medication was stopped (if applicable)"
                ),
                .builtIn(
                    id: BuiltInFieldIds.Medication.prescribedBy,
                    displayName: "Prescribed By",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 6,
                    placeholder: "e.g., Dr. Williams",
                    helpText: "Healthcare provider who prescribed this medication",
                    validationRules: [.maxLength(200)],
                    capitalizationMode: .words
                ),
                .builtIn(
                    id: BuiltInFieldIds.Medication.pharmacy,
                    displayName: "Pharmacy",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 7,
                    placeholder: "e.g., Walgreens",
                    helpText: "Pharmacy where prescription is filled",
                    validationRules: [.maxLength(200)],
                    capitalizationMode: .words
                ),
                .builtIn(
                    id: BuiltInFieldIds.Medication.refillsRemaining,
                    displayName: "Refills Remaining",
                    fieldType: .int,
                    isRequired: false,
                    displayOrder: 8,
                    placeholder: "e.g., 3",
                    helpText: "Number of refills remaining",
                    validationRules: [.minValue(0)]
                ),
                .builtIn(
                    id: BuiltInFieldIds.Medication.notes,
                    displayName: "Notes",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 9,
                    placeholder: "Any additional notes",
                    helpText: "Additional information or side effects",
                    validationRules: [.maxLength(2_000)],
                    isMultiline: true
                ),
                .builtIn(
                    id: BuiltInFieldIds.Medication.attachmentIds,
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
                .builtIn(
                    id: BuiltInFieldIds.Allergy.allergen,
                    displayName: "Allergen",
                    fieldType: .string,
                    isRequired: true,
                    displayOrder: 1,
                    placeholder: "e.g., Peanuts, Penicillin, Pollen",
                    helpText: "What causes the allergic reaction",
                    validationRules: [.minLength(1), .maxLength(200)],
                    capitalizationMode: .words
                ),
                .builtIn(
                    id: BuiltInFieldIds.Allergy.severity,
                    displayName: "Severity",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 2,
                    placeholder: "e.g., Mild, Moderate, Severe, Life-threatening",
                    helpText: "Severity of the allergic reaction",
                    validationRules: [.maxLength(50)]
                ),
                .builtIn(
                    id: BuiltInFieldIds.Allergy.reaction,
                    displayName: "Reaction",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 3,
                    placeholder: "e.g., Hives, Swelling, Anaphylaxis",
                    helpText: "Type of allergic reaction",
                    validationRules: [.maxLength(200)]
                ),
                .builtIn(
                    id: BuiltInFieldIds.Allergy.diagnosedDate,
                    displayName: "Date Diagnosed",
                    fieldType: .date,
                    isRequired: false,
                    displayOrder: 4,
                    helpText: "When the allergy was diagnosed"
                ),
                .builtIn(
                    id: BuiltInFieldIds.Allergy.notes,
                    displayName: "Notes",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 5,
                    placeholder: "Any additional notes",
                    helpText: "Additional information or treatment details",
                    validationRules: [.maxLength(2_000)],
                    isMultiline: true
                ),
                .builtIn(
                    id: BuiltInFieldIds.Allergy.attachmentIds,
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
                .builtIn(
                    id: BuiltInFieldIds.Note.title,
                    displayName: "Title",
                    fieldType: .string,
                    isRequired: true,
                    displayOrder: 1,
                    placeholder: "e.g., Doctor Visit, Lab Results",
                    helpText: "Brief title for this note",
                    validationRules: [.minLength(1), .maxLength(200)],
                    capitalizationMode: .words
                ),
                .builtIn(
                    id: BuiltInFieldIds.Note.content,
                    displayName: "Content",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 2,
                    placeholder: "Notes and details",
                    helpText: "Full content of the note",
                    validationRules: [.maxLength(10_000)],
                    isMultiline: true
                ),
                .builtIn(
                    id: BuiltInFieldIds.Note.attachmentIds,
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
