//
//  TextProcessing.swift
//  swift-obj-c
//
//  The seam. Everything the ViewModel is allowed to know about "processing"
//  is declared here, and this file contains no Objective-C types at all —
//  that is what makes the layer rule in the PRD enforceable by the compiler
//  rather than by discipline.
//

/// The capability the ViewModel depends on.
///
/// Declared `Sendable` so a conforming service can be shared across isolation
/// domains. In this project the service is main-actor isolated (see
/// `SWIFT_DEFAULT_ACTOR_ISOLATION`), which is what makes that safe.
protocol TextProcessing: Sendable {

    /// Transforms `text` into a `ProcessingResult`, or throws a
    /// `TextProcessingError` describing what went wrong.
    func process(text: String) throws -> ProcessingResult
}

/// Everything that can go wrong, expressed in Swift.
///
/// Objective-C's `NSError` is translated into these cases inside
/// `TextProcessingService` and never travels further up. That translation is
/// the whole point of this type: above the service, failure is just Swift.
enum TextProcessingError: LocalizedError, Equatable {

    /// Objective-C rejected the input: more than 1,000 UTF-16 code units.
    case inputTooLong

    /// Any other failure, carrying its description for diagnosis.
    case unknown(String)

    /// `LocalizedError` conformance — what SwiftUI shows to the user.
    var errorDescription: String? {
        switch self {
        case .inputTooLong:
            return "That text is too long to process. Keep it under 1,000 characters."
        case .unknown(let detail):
            return "Processing failed: \(detail)"
        }
    }
}
