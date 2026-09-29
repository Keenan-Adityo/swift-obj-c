//
//  DBTextUtility.h
//  swift-obj-c
//
//  A small "legacy-style" string utility written in Objective-C.
//
//  This header is the public face of the class: it declares WHAT the class
//  does, not HOW. In Phase 2 it gets imported by the bridging header so the
//  Swift compiler can see it and build Swift signatures out of it.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Every error that crosses the Objective-C → Swift boundary carries this
/// domain. Swift code translates it into its own error type, so nothing above
/// the service layer ever sees an `NSError`.
extern NSErrorDomain const DBTextUtilityErrorDomain;

/// `NS_ERROR_ENUM` ties the enum to its domain above, which lets Swift import
/// it as `DBTextUtilityError` — a type that already conforms to `Error`.
typedef NS_ERROR_ENUM(DBTextUtilityErrorDomain, DBTextUtilityError) {
    /// Input exceeded the 1,000 UTF-16 unit limit.
    DBTextUtilityErrorInputTooLong = 1,
};

@interface DBTextUtility : NSObject

/// Uppercases the text.
/// Objective-C selector: `uppercaseText:` → imported to Swift as `uppercased(_:)`.
- (NSString *)uppercaseText:(NSString *)text
    NS_SWIFT_NAME(uppercased(_:));

/// Reverses the text while keeping composed characters (emoji) intact.
/// Objective-C selector: `reverseText:` → imported to Swift as `reversed(_:)`.
- (NSString *)reverseText:(NSString *)text
    NS_SWIFT_NAME(reversed(_:));

/// Returns `NSString.length`, which counts UTF-16 code units — NOT the number
/// of characters a user sees. `👨‍👩‍👧` counts as 8 here and 1 in Swift's
/// `String.count`. That difference is the point of this method.
/// Imported to Swift as `utf16Length(of:)`.
- (NSInteger)characterCount:(NSString *)text
    NS_SWIFT_NAME(utf16Length(of:));

/// Validates the input before it is processed.
/// Returns `nil` and fills `error` when the text exceeds 1,000 UTF-16 units.
/// Objective-C's `NSError **` idiom imports into Swift as a `throws` function.
- (nullable NSString *)validatedText:(NSString *)text
                               error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
