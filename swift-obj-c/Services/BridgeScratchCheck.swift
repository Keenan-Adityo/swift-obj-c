//
//  BridgeScratchCheck.swift
//  swift-obj-c
//
//  PHASE 2 SCRATCH CHECK — the first Swift code in this project that touches
//  an Objective-C type. It proves the bridging header two different ways:
//
//  1. COMPILE TIME — the `let _: (…) -> …` lines pin down the exact Swift
//     signatures that were generated from DBTextUtility.h. Drop a nullability
//     annotation, change an NS_SWIFT_NAME, or point the bridging header at the
//     wrong file, and these lines stop compiling.
//
//  2. RUN TIME — `run()` calls the real Objective-C implementation and logs
//     what came back, so the values are observable, not just assumed.
//
//  Phase 3 moves this responsibility into TextProcessingService, which becomes
//  the only file allowed to reference DB* types.
//

import Foundation
import OSLog

enum BridgeScratchCheck {

    private static let logger = Logger(subsystem: "DevBridge", category: "Phase2Bridge")

    /// Type-level proof of what the Swift importer produced from the header.
    /// These lines are the contract; changing the header changes them.
    private static func proveImportedSignatures() {
        let utility = DBTextUtility()

        // NS_SWIFT_NAME(uppercased(_:)) — without the annotation this would
        // import as `uppercaseText(_:)`, and this line would not compile.
        let _: (String) -> String = utility.uppercased

        // NS_SWIFT_NAME(reversed(_:))
        let _: (String) -> String = utility.reversed

        // NS_SWIFT_NAME(utf16Length(of:)) — NSInteger arrives as Swift Int.
        let _: (String) -> Int = utility.utf16Length(of:)

        // `nullable ... error:(NSError **)` arrives as a THROWS function that
        // returns a non-optional String — the nullability is consumed by `try`.
        let _: (String) throws -> String = utility.validatedText

        // The class itself arrived as a normal Swift type, no `!` anywhere.
        let _: DBTextUtility.Type = DBTextUtility.self
    }

    /// Calls the Objective-C implementation and logs what crossed the boundary.
    static func run() {
        proveImportedSignatures()

        let utility = DBTextUtility()
        let sample = "Hello Swift"
        let family = "👨‍👩‍👧"
        let overlong = String(repeating: "a", count: 1_001)

        // Swift → Objective-C call, results back as plain Swift values.
        let uppercased = utility.uppercased(sample)
        let reversed = utility.reversed(sample)
        let utf16 = utility.utf16Length(of: sample)
        let familyUTF16 = utility.utf16Length(of: family)

        // Objective-C rejection arrives in Swift as a thrown error. (Phase 3
        // maps it to TextProcessingError; right now we just observe it.)
        var rejection = "accepted"
        do {
            _ = try utility.validatedText(overlong)
        } catch {
            rejection = "threw: \(error)"
        }

        let report = """

        ---- Phase 2 bridge check ----
        uppercased(\(sample.debugDescription))            = \(uppercased)
        reversed(\(sample.debugDescription))              = \(reversed)
        utf16Length(of: \(sample.debugDescription))       = \(utf16)   | String.count = \(sample.count)
        utf16Length(of: \(family.debugDescription))   = \(familyUTF16)   | String.count = \(family.count)
        validatedText(1001 units)                      -> \(rejection)
        ------------------------------
        """

        logger.info("\(report, privacy: .public)")
    }
}
