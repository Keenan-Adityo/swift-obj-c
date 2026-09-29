//
//  DBTextUtility.m
//  swift-obj-c
//
//  The implementation. Note that only Foundation is imported: Objective-C in
//  this project must never know about UIKit, SwiftUI, or any Swift type.
//

#import "DBTextUtility.h"

/// Longest input the utility accepts, measured in UTF-16 code units.
static const NSUInteger DBTextUtilityMaximumLength = 1000;

NSErrorDomain const DBTextUtilityErrorDomain = @"DevBridge.DBTextUtilityErrorDomain";

@implementation DBTextUtility

- (NSString *)uppercaseText:(NSString *)text {
    // Message send: ask the `text` object to uppercase itself.
    // Locale-independent by default, which is what the tests expect.
    return [text uppercaseString];
}

- (NSString *)reverseText:(NSString *)text {
    // Walking backwards by UTF-16 unit would split surrogate pairs and turn
    // emoji into garbage, so each step moves one *composed character sequence*
    // (an emoji, or a base letter plus its combining accent) at a time.
    NSMutableString *reversed = [NSMutableString stringWithCapacity:text.length];

    NSUInteger index = text.length;
    while (index > 0) {
        NSRange range = [text rangeOfComposedCharacterSequenceAtIndex:index - 1];
        [reversed appendString:[text substringWithRange:range]];
        // Jump to the composed character that starts *before* this one, so the
        // next pass never lands in the middle of a sequence we already copied.
        index = range.location;
    }

    return [reversed copy];
}

- (NSInteger)characterCount:(NSString *)text {
    // Deliberately UTF-16 code units, not grapheme clusters. FR-05 requires
    // both numbers to be shown side by side in the UI.
    return (NSInteger)text.length;
}

- (nullable NSString *)validatedText:(NSString *)text error:(NSError **)error {
    if (text.length <= DBTextUtilityMaximumLength) {
        return text;
    }

    // NSError ** convention: fill the out-parameter only on failure, and
    // return nil. `if (error)` guards against callers passing NULL.
    if (error != NULL) {
        NSString *message = [NSString stringWithFormat:
                             @"Input is too long: %lu UTF-16 units received, %lu maximum.",
                             (unsigned long)text.length,
                             (unsigned long)DBTextUtilityMaximumLength];
        *error = [NSError errorWithDomain:DBTextUtilityErrorDomain
                                     code:DBTextUtilityErrorInputTooLong
                                 userInfo:@{NSLocalizedDescriptionKey: message}];
    }

    return nil;
}

@end
