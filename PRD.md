# DevBridge — Product Requirements Document (v2)

## 1. Overview

**DevBridge** is a small iOS demo app that shows Objective-C, Swift and SwiftUI working together in one app. The user types text, taps a button, and sees results computed by an Objective-C utility, surfaced through a Swift service and ViewModel, and rendered by SwiftUI.

This is a learning project. Clarity beats production polish, but the code should follow current interop conventions so what is learned transfers to real codebases.

### Goals

1. Show Swift calling Objective-C (bridging header, nullability, naming, error handling).
2. Show Objective-C calling back into Swift (delegate, block, notification).
3. Show Swift models and state driving SwiftUI.
4. Show a Swift abstraction layer isolating "legacy" Objective-C.
5. Surface the real boundary pitfalls: string semantics, threading, ownership.

### Non-goals

Backend, networking, authentication, persistence (Core Data/SwiftData), third-party libraries, custom design systems, complex animation, complex UIKit screens.

---

## 2. Assumptions and Constraints

| Item | Decision |
| --- | --- |
| Xcode | 16 or later |
| Deployment target | iOS 17.0 (required for `@Observable`) |
| Swift language mode | Swift 6 with strict concurrency **complete** (fall back to Swift 5 mode only if a specific blocker is documented) |
| UI | SwiftUI only |
| Interop mechanism | Bridging header (app target) |
| Dependencies | None |
| Fallback | If iOS 16 is ever needed: `ObservableObject` + `@Published` |

---

## 3. Architecture

```text
SwiftUI View (ContentView)
        │  user action
        ▼
DevBridgeViewModel   (@MainActor, @Observable)
        │  depends on protocol
        ▼
TextProcessing (Swift protocol)
        │
        ▼
TextProcessingService  (Swift, only place that touches Obj-C types)
        │  Swift → Obj-C call
        ▼
DBTextUtility / DBTextProcessor  (Objective-C)
```

### Layer rules

- Views know only the ViewModel.
- The ViewModel knows only the `TextProcessing` protocol, never `DB*` types.
- Only `TextProcessingService` (and its delegate adapter) imports or references Objective-C types.
- Objective-C contains no UI code and no knowledge of Swift types beyond what the auto-generated header exposes.

> **Rule of the project:** no `DB*` symbol may appear in any View or ViewModel file. This is checked in acceptance criteria.

---

## 4. Functional Requirements

### Version 1 — Core

| ID | Requirement |
| --- | --- |
| FR-01 | The app provides a text field for arbitrary input. |
| FR-02 | A **Process Text** button triggers processing. |
| FR-03 | Processing returns: original text, uppercase text, reversed text, UTF-16 length, and grapheme count (see FR-05). |
| FR-04 | Results are shown in labeled sections and update automatically when state changes. |
| FR-05 | **Character count semantics.** The Obj-C utility returns `NSString.length` (UTF-16 code units). Swift computes `String.count` (grapheme clusters). The UI shows both, labeled *"UTF-16 units (Obj-C)"* and *"Characters (Swift)"*, so the difference is visible. |
| FR-06 | Empty or whitespace-only input disables the button and shows a placeholder message. It never crashes. |
| FR-07 | Processing an input that Obj-C rejects (e.g., over 1,000 characters) surfaces a user-readable error via `NSError` → Swift `throws` (see 6.3). |
| FR-08 | An "Architecture" section shows SwiftUI → Swift → Objective-C. |

### Version 2 — Advanced interop

| ID | Requirement |
| --- | --- |
| FR-20 | **Delegate:** `DBTextProcessor` reports completion to a `DBTextProcessorDelegate`, implemented in Swift. |
| FR-21 | **Block/closure:** the same processor offers a completion-block variant, imported in Swift as a closure. |
| FR-22 | **Notification:** Obj-C posts `DBTextProcessingDidFinishNotification`; Swift observes it and updates state. |
| FR-23 | **Nullable values:** at least one Obj-C method returns `nullable NSString *`, shown as a Swift `String?` in the UI. |
| FR-24 | **Threading:** the processor completes on a background queue; Swift hops to the main actor before touching UI state. |
| FR-25 | **Comparison note:** the README explains when to choose delegate vs block vs notification. |

---

## 5. Objective-C Specification

### 5.1 `DBTextUtility` (Version 1)

```objc
// DBTextUtility.h
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const DBTextUtilityErrorDomain;

typedef NS_ERROR_ENUM(DBTextUtilityErrorDomain, DBTextUtilityError) {
    DBTextUtilityErrorInputTooLong = 1,
};

@interface DBTextUtility : NSObject

- (NSString *)uppercaseText:(NSString *)text
    NS_SWIFT_NAME(uppercased(_:));

- (NSString *)reverseText:(NSString *)text
    NS_SWIFT_NAME(reversed(_:));

/// Returns NSString.length (UTF-16 code units), not grapheme count.
- (NSInteger)characterCount:(NSString *)text
    NS_SWIFT_NAME(utf16Length(of:));

/// Returns nil and sets error if text exceeds 1,000 UTF-16 units.
- (nullable NSString *)validatedText:(NSString *)text
                               error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
```

Requirements:

- Every header uses `NS_ASSUME_NONNULL_BEGIN/END`; anything optional is explicitly `nullable`.
- Use `NS_SWIFT_NAME` on at least two methods, and document the auto-renamed vs. custom-named Swift signature side by side in the README.
- `.m` implementation uses no UIKit/SwiftUI imports.
- `NSInteger` bridges to Swift `Int`; the README notes this.

### 5.2 `DBTextProcessor` (Version 2)

```objc
NS_ASSUME_NONNULL_BEGIN

@class DBTextProcessor;

@protocol DBTextProcessorDelegate <NSObject>
- (void)textProcessor:(DBTextProcessor *)processor
       didFinishWithResult:(NSString *)result;
@optional
- (void)textProcessor:(DBTextProcessor *)processor
       didFailWithError:(NSError *)error;
@end

@interface DBTextProcessor : NSObject

/// Weak: the delegate must not be retained (avoids retain cycles).
@property (nonatomic, weak, nullable) id<DBTextProcessorDelegate> delegate;

- (void)processText:(NSString *)text;

- (void)processText:(NSString *)text
         completion:(void (^)(NSString * _Nullable result,
                              NSError * _Nullable error))completion;

@end

extern NSNotificationName const DBTextProcessingDidFinishNotification;

NS_ASSUME_NONNULL_END
```

Requirements:

- `delegate` is `weak`.
- Work runs on a background queue; **delegate, block and notification are all delivered on that background queue** (documented in header comments). This is deliberate so Swift must handle the hop to the main actor.
- The notification's `userInfo` contains a documented key for the result string.

---

## 6. Swift Specification

### 6.1 Bridging

- `DevBridge-Bridging-Header.h` imports `DBTextUtility.h` (and `DBTextProcessor.h` in V2).
- `SWIFT_OBJC_BRIDGING_HEADER` build setting points at it.
- README notes: bridging headers apply to **app targets**; frameworks use umbrella headers and modules.
- For the reverse direction, README explains `NSObject` inheritance, `@objc`, and the generated `DevBridge-Swift.h`, and why the delegate adapter needs them.

### 6.2 Model

```swift
struct ProcessingResult: Equatable, Sendable {
    let originalText: String
    let uppercaseText: String
    let reversedText: String
    let utf16Length: Int      // from Objective-C
    let characterCount: Int   // from Swift String.count
}
```

### 6.3 Service and protocol

```swift
protocol TextProcessing: Sendable {
    func process(text: String) throws -> ProcessingResult
}

enum TextProcessingError: LocalizedError, Equatable {
    case inputTooLong
    case unknown(String)
    var errorDescription: String? { /* user-readable */ }
}

final class TextProcessingService: TextProcessing {
    private let utility = DBTextUtility()

    func process(text: String) throws -> ProcessingResult {
        // 1. Call validatedText(_:) (Obj-C NSError** becomes `throws`)
        // 2. Map DBTextUtilityError → TextProcessingError
        // 3. Build ProcessingResult, computing text.count in Swift
    }
}
```

Notes:

- `- (nullable NSString *)validatedText:error:` imports as `func validatedText(_:) throws -> String`.
- If `DBTextUtility` is not `Sendable`-safe under strict concurrency, either confine it inside the service or mark the wrapper `@unchecked Sendable` **with a comment explaining why** (the class holds no mutable state).
- Obj-C error domain/codes are translated into Swift errors; the ViewModel never sees `NSError`.

### 6.4 ViewModel

```swift
@MainActor
@Observable
final class DevBridgeViewModel {
    var inputText = ""
    private(set) var result: ProcessingResult?
    private(set) var errorMessage: String?

    private let service: TextProcessing

    init(service: TextProcessing = TextProcessingService()) {
        self.service = service
    }

    var canProcess: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func processText() {
        do {
            result = try service.process(text: inputText)
            errorMessage = nil
        } catch {
            result = nil
            errorMessage = error.localizedDescription
        }
    }
}
```

### 6.5 Version 2 delegate adapter

- `TextProcessorDelegateAdapter: NSObject, DBTextProcessorDelegate` lives in the Swift service layer.
- Callbacks arrive off the main thread; the adapter forwards via an `AsyncStream` or `Task { @MainActor in … }`.
- The service owns the `DBTextProcessor` and the adapter; the processor holds the adapter **weakly**.
- Notification observation uses `NotificationCenter.default.notifications(named:)` (async sequence) or a block-based observer whose token is stored and removed on deinit.

---

## 7. UI Specification

`ContentView` wraps a `ScrollView` inside a `NavigationStack` so large Dynamic Type and small screens never clip content.

Sections, in order:

1. **Header:** "DevBridge" / "Obj-C + Swift + SwiftUI"
2. **Input:** `TextField` with label "Enter text"
3. **Action:** "Process Text" button, disabled when `canProcess` is false
4. **Result:** Original, Uppercase, Reversed, UTF-16 units (Obj-C), Characters (Swift)
5. **Error/empty state:** inline message
6. **Architecture:** SwiftUI ↓ Swift ↓ Objective-C

Style: system fonts, standard components, light/dark compatible, no external UI libraries.

Accessibility:

- Every control has a meaningful accessibility label.
- Result rows are combined into single elements (`accessibilityElement(children: .combine)`).
- Layout remains usable at the largest accessibility text size.

---

## 8. Non-Functional Requirements

| Area | Requirement |
| --- | --- |
| Build hygiene | Zero warnings, including static analyzer |
| Concurrency | No data-race warnings under strict concurrency; ViewModel is `@MainActor` |
| Memory | No retain cycles across the boundary (delegate `weak`, observer tokens removed) |
| Threading | Callback thread is documented; UI state is only mutated on the main actor |
| Portability | No private APIs, no dependencies |
| Documentation | README with diagrams and the comparison notes listed in FR-25 |

---

## 9. Testing Requirements

Add a unit test target (Swift Testing or XCTest).

| Test | Purpose |
| --- | --- |
| `DBTextUtility` uppercase/reverse/length | Verifies Obj-C called directly from Swift |
| Grapheme test: `"👨‍👩‍👧"` → UTF-16 length 8, Swift count 1 | Proves the boundary difference |
| Empty string | Defined behavior, no crash |
| Over-length input | Throws `TextProcessingError.inputTooLong` |
| `TextProcessingService` mapping | Obj-C errors become Swift errors |
| `DevBridgeViewModel` with a mock `TextProcessing` | Demonstrates value of the protocol seam |
| (V2) Delegate/block/notification | Async expectation; asserts delivery, then main-actor state update |
| (V2) Delegate lifetime | Adapter deallocates; no leak |

---

## 10. Project Structure

```text
DevBridge/
├── App/DevBridgeApp.swift
├── Views/ContentView.swift
├── ViewModels/DevBridgeViewModel.swift
├── Models/ProcessingResult.swift
├── Services/
│   ├── TextProcessing.swift             (protocol + error type)
│   ├── TextProcessingService.swift
│   └── TextProcessorDelegateAdapter.swift   (V2)
├── ObjectiveC/
│   ├── DBTextUtility.h / .m
│   └── DBTextProcessor.h / .m               (V2)
├── DevBridge-Bridging-Header.h
└── DevBridgeTests/
```

Folder layout may follow Xcode conventions as long as the layer rules in section 3 hold.

---

## 11. Data Flow (Version 1)

```text
User taps "Process Text"
  → ContentView calls viewModel.processText()
  → ViewModel calls service.process(text:) via TextProcessing protocol
  → Service calls DBTextUtility (Swift → Obj-C)
  → Obj-C returns NSString / NSInteger / NSError
  → Service maps values into ProcessingResult (or throws a Swift error)
  → ViewModel updates result / errorMessage
  → @Observable triggers SwiftUI re-render
```

### Version 2 flow (callback)

```text
ViewModel → Service → DBTextProcessor.processText (background queue)
  → Obj-C calls delegate / block / posts notification (background queue)
  → Adapter hops to @MainActor
  → ViewModel state updates → SwiftUI re-renders
```

---

## 12. Acceptance Criteria

### Version 1 is done when all are true

- [ ] Project builds with zero warnings on Xcode 16+, iOS 17 target.
- [ ] Input `"Hello Swift"` produces `HELLO SWIFT`, `tfiwS olleH`, UTF-16 units `11`, characters `11`.
- [ ] Input `"👨‍👩‍👧"` shows UTF-16 units `8` and characters `1`.
- [ ] Empty/whitespace input disables the button and never crashes.
- [ ] Over-length input shows a readable error produced from an Obj-C `NSError`.
- [ ] Removing the bridging header from build settings breaks the build (proves the bridge is real).
- [ ] A search for `DB` type names in `Views/` and `ViewModels/` returns no matches.
- [ ] All Obj-C headers use nullability annotations; the imported Swift signatures show no `!`.
- [ ] At least two `NS_SWIFT_NAME` usages are documented in the README.
- [ ] Unit tests in section 9 (V1 rows) pass.
- [ ] UI is usable in light mode, dark mode and the largest Dynamic Type size.

### Version 2 is done when all are true

- [ ] Delegate, block and notification paths each update the UI correctly.
- [ ] Callbacks are proven to arrive off the main thread (test asserts `!Thread.isMainThread`) and UI state changes only on the main actor.
- [ ] No strict-concurrency warnings.
- [ ] Delegate adapter deallocates in a leak test.
- [ ] A nullable Obj-C return is displayed as a Swift optional in the UI.
- [ ] README comparison of delegate vs block vs notification is written.

---

## 13. Milestones

| # | Milestone | Outcome |
| --- | --- | --- |
| M1 | Objective-C class | `DBTextUtility` compiles, with nullability, `NS_SWIFT_NAME`, and error API |
| M2 | Bridge | Bridging header configured; Swift calls Obj-C from a scratch test |
| M3 | Service and model | `TextProcessing` protocol, service, `ProcessingResult`, error mapping |
| M4 | ViewModel and UI | Full V1 flow works on screen |
| M5 | Tests and hygiene | V1 tests pass, zero warnings, README started |
| M6 | Delegate and block | `DBTextProcessor` with weak delegate and completion block |
| M7 | Notification and threading | Notification path, main-actor hop, leak and thread tests |
| M8 | Wrap-up | README comparison notes and architecture diagram finalized |

---

## 14. Open Questions

1. Should the Obj-C processor use its own serial queue or a global concurrent queue?
2. Should a later version move `DBTextUtility` into a static library or framework to demonstrate umbrella headers and module maps?
3. Is Swift 6 language mode acceptable from the start, or should the project begin in Swift 5 mode and migrate as an exercise?

---

## Appendix A — Learning Exercises (separate from product scope)

These are a study guide, not product requirements. Do them by hand rather than delegating to an AI agent.

1. Create the Obj-C class manually; explain what `.h` and `.m` are for.
2. Add the bridging header and explain what it exposes.
3. Call `DBTextUtility()` from Swift and inspect its imported signatures (Xcode → Jump to Definition → Swift interface).
4. Turn Obj-C output into `ProcessingResult`.
5. Change the Obj-C implementation (e.g., reverse by words) and observe the UI.
6. Implement `DBTextProcessorDelegate` in Swift; note why `NSObject` and `@objc` are needed.
7. Break the interop on purpose: remove `nullable`, make the delegate `strong`, call back on the wrong thread. Observe each failure.
8. Trace a button press through every layer and draw the diagram from memory.

## Appendix B — Success Statement

> SwiftUI handles the UI; Swift handles state and application logic; Objective-C provides a legacy-style utility that Swift consumes through the interoperability layer. Values crossing the boundary (strings, integers, errors, callbacks) are mapped into Swift types at the service layer, so nothing above it needs to know Objective-C exists.
