//
//  DevBridge-Bridging-Header.h
//
//  THE language boundary, in one file.
//
//  The Swift compiler cannot see Objective-C headers on its own. This file is
//  the list of headers it is allowed to read, and it is wired up by the
//  SWIFT_OBJC_BRIDGING_HEADER build setting on the app target.
//
//  Nothing in the app imports this file directly — the compiler does.
//  Remove the build setting and every Swift reference to a DB* type fails
//  to compile, which is how you prove the bridge is real.
//

// Phase 2: DBTextUtility.
// Phase 6 will add: #import "ObjectiveC/DBTextProcessor.h"
#import "ObjectiveC/DBTextUtility.h"
