//
//  ProcessingResult.swift
//  swift-obj-c
//
//  A pure Swift value: everything one processing pass produced.
//
//  Note what is ABSENT here — no Objective-C type appears. The values crossed
//  the language boundary down inside TextProcessingService and arrived as
//  plain Swift values. Nothing above the service knows Objective-C exists.
//

/// Immutable snapshot of a single processing pass.
///
/// `Equatable` so tests can assert on whole results at once.
/// `Sendable` because it is a value type that may cross isolation domains.
struct ProcessingResult: Equatable, Sendable {

    /// Exactly what the user typed, unmodified.
    let originalText: String

    /// From Objective-C: `DBTextUtility.uppercased(_:)`.
    let uppercaseText: String

    /// From Objective-C: `DBTextUtility.reversed(_:)`.
    let reversedText: String

    /// From Objective-C: `DBTextUtility.utf16Length(of:)` — counts UTF-16
    /// code units. For `👨‍👩‍👧` this is 8.
    let utf16Length: Int

    /// From Swift: `String.count` — counts grapheme clusters (what a person
    /// would call "characters"). For `👨‍👩‍👧` this is 1.
    /// `utf16Length` and `characterCount` deliberately disagree; showing both
    /// is FR-05.
    let characterCount: Int
}
