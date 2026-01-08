import UIKit

/// Determines how an attachment thumbnail should be displayed
///
/// This enum extracts the display logic from AttachmentThumbnailView into a testable component.
/// The View can use this to decide which content to render without embedding the logic in the body.
enum ThumbnailDisplayMode: Equatable {
    /// Display the actual thumbnail image
    case thumbnail(Data)

    /// Display a PDF document icon
    case pdfIcon

    /// Display an image placeholder icon (when thumbnail not available)
    case imageIcon

    /// Display a generic file icon
    case genericFileIcon

    /// Determine the display mode for an attachment
    ///
    /// - Parameter attachment: The attachment to display
    /// - Returns: The appropriate display mode based on attachment properties
    static func from(_ attachment: Attachment) -> ThumbnailDisplayMode {
        if let thumbnailData = attachment.thumbnailData, !thumbnailData.isEmpty {
            .thumbnail(thumbnailData)
        } else if attachment.isPDF {
            .pdfIcon
        } else if attachment.isImage {
            .imageIcon
        } else {
            .genericFileIcon
        }
    }

    /// System image name for the icon
    var systemImageName: String {
        switch self {
        case .thumbnail:
            "photo" // Not used for thumbnails
        case .pdfIcon:
            "doc.fill"
        case .imageIcon:
            "photo.fill"
        case .genericFileIcon:
            "doc.fill"
        }
    }

    /// Icon color for the display mode
    var iconColorName: String {
        switch self {
        case .thumbnail:
            "clear"
        case .pdfIcon:
            "red"
        case .imageIcon:
            "blue"
        case .genericFileIcon:
            "gray"
        }
    }

    /// Whether this mode displays an actual thumbnail image
    var hasThumbnailImage: Bool {
        if case .thumbnail = self {
            return true
        }
        return false
    }
}
