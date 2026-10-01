//
//  TextProcessingService.swift
//  swift-obj-c
//
//  THE boundary file. Together with DevBridge-Bridging-Header.h, this is the
//  only place in the app that references a DB* type. If Objective-C ever
//  changes, this is the only file that changes with it.
//

import Foundation

final class TextProcessingService: TextProcessing {

    /// `DBTextUtility` is deliberately kept private here: the instance never
    /// escapes, so no other layer can reach Objective-C through it.
    ///
    /// On concurrency: `DBTextUtility` is a non-Sendable Objective-C class.
    /// It is safe because this service never leaves the main actor (the
    /// project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so this class
    /// is main-actor isolated by default) and the utility holds no mutable
    /// state. Confining it beats marking the wrapper `@unchecked Sendable`.
    private let utility = DBTextUtility()

    /// Explicitly `nonisolated`, and only for construction.
    ///
    /// The ViewModel's default argument (`= TextProcessingService()`) is
    /// evaluated outside actor isolation, so a main-actor `init()` would warn.
    /// Making just the initializer nonisolated fixes that without changing the
    /// API — every *method* below still runs on the main actor, which is what
    /// confines the Objective-C utility.
    nonisolated init() {}

    func process(text: String) throws -> ProcessingResult {

        // 1. Objective-C validates first. Its `NSError **` parameter arrives
        //    in Swift as a `throws`, so the failure path is idiomatic Swift.
        let validated: String
        do {
            validated = try utility.validatedText(text)
        } catch {
            // 2. Translate BEFORE returning: the NSError is consumed here and
            //    a Swift error leaves instead.
            throw Self.translate(error)
        }

        // 3. Swift → Objective-C calls. Obj-C answers with NSString/NSInteger,
        //    which the bridging layer has already turned into String/Int.
        return ProcessingResult(
            originalText: text,
            uppercaseText: utility.uppercased(validated),
            reversedText: utility.reversed(validated),
            utf16Length: utility.utf16Length(of: validated),
            // 4. Computed in Swift, on purpose. This number is supposed to
            //    differ from the Objective-C one (FR-05).
            characterCount: validated.count
        )
    }

    /// Maps an Objective-C error onto the Swift error type, once and for all.
    /// The domain and code were declared in DBTextUtility.h via NS_ERROR_ENUM.
    private static func translate(_ error: any Error) -> TextProcessingError {
        let nsError = error as NSError
        if nsError.domain == DBTextUtilityErrorDomain,
           nsError.code == DBTextUtilityError.inputTooLong.rawValue {
            return .inputTooLong
        }
        return .unknown(nsError.localizedDescription)
    }
}
