import SwiftUI

/// SwiftUI-specific extension for TextCapitalizationMode
///
/// Separated from the model layer to keep FieldDefinition framework-agnostic.
extension TextCapitalizationMode {
    /// Convert to SwiftUI's TextInputAutocapitalization
    var toSwiftUI: TextInputAutocapitalization {
        switch self {
        case .none:
            .never
        case .words:
            .words
        case .sentences:
            .sentences
        case .allCharacters:
            .characters
        }
    }
}
