# AGENTS.md

## Non-Negotiables

These rules always apply.

1. **No Git changes.** Never commit, amend, push, branch, merge, rebase, reset, or run any destructive Git command. Read-only commands (`git status`, `git diff`, `git log`) are allowed. The developer owns all Git operations.
2. **No third-party dependencies.** Apple frameworks only: Swift Standard Library, Foundation, SwiftUI, Observation, XCTest.
3. **No deleting files, and no overwriting code you don't understand.** Don't touch project configuration unrelated to the current task. Don't remove existing functionality to simplify work.
4. **One phase at a time.** Finish a phase, summarize it, and wait for the developer's confirmation before starting the next.
5. **Keep the language boundary visible.** Never hide Objective-C/Swift interop behind abstractions.
6. **When unsure, ask.** Don't guess about requirements, project settings, or which phase we're in.

---

## Project Overview

DevBridge is a small, educational iOS app for learning how **Objective-C**, **Swift**, and **SwiftUI** work together in one application.

The most important goal is to make the language boundaries visible and understandable. The developer must be able to explain every step of this flow:

```text
User → SwiftUI → ViewModel → Swift Service → Objective-C → Swift → ViewModel State → SwiftUI
```

The app is intentionally tiny. Do not add complexity.

---

## Project Settings

Adjust these values to match the actual project. If a value is missing or unclear, ask before assuming.

| Setting | Value |
|---|---|
| Deployment target | iOS 17.0 (required for `@Observable`) |
| Xcode / Swift | Xcode 16, Swift 5 language mode |
| Class prefix (Objective-C) | `DB` |
| Bridging header | `DevBridge-Bridging-Header.h` (`SWIFT_OBJC_BRIDGING_HEADER` build setting) |
| Test framework | XCTest only (do not mix in Swift Testing) |

**Xcode project handling:** The agent must not hand-edit `project.pbxproj` unless asked. When a new file must be added to a target, or a Build Setting must change, tell the developer exactly what to do in Xcode, or ask permission to edit the project file.

**Build and test commands** (adjust simulator name as needed):

```bash
xcodebuild build -scheme DevBridge -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test  -scheme DevBridge -destination 'platform=iOS Simulator,name=iPhone 16'
```

Run these to verify work before declaring a phase complete.

---

## Architecture

Use **MVVM**. Recommended structure (adjust to Xcode conventions; target membership matters more than folder layout):

```text
DevBridge/
├── App/            DevBridgeApp.swift
├── Views/          ContentView.swift
├── ViewModels/     DevBridgeViewModel.swift
├── Models/         ProcessingResult.swift
├── Services/       TextProcessingService.swift
├── ObjectiveC/     DBTextUtility.h / DBTextUtility.m
├── Tests/          DevBridgeTests/ (Swift), ObjectiveCTests/
└── DevBridge-Bridging-Header.h
```

### Layer responsibilities

| Layer | Language | Does | Must not |
|---|---|---|---|
| View | SwiftUI | Presentation, user input, observing state | Contain business logic or call Objective-C |
| ViewModel | Swift | Hold screen state, receive user actions, call the service, map results to UI state | Know Objective-C implementation details |
| Service | Swift | The **only** place that talks to Objective-C; converts types across the boundary | Contain UI logic |
| Objective-C utility | Objective-C | Small "legacy-style" logic: uppercase, character count, string reversal | Contain SwiftUI or UI logic |

Bad (business logic in the view):

```swift
Button("Process") {
    let utility = DBTextUtility()
    // logic here
}
```

Good:

```swift
Button("Process") { viewModel.processText() }
```

Do not create names like `UniversalLanguageBridgeManager` or `InteropCoordinator`. Simple code wins.

---

## Objective-C Conventions

The Objective-C code should be small but **interop-friendly**, so Swift sees clean types:

- Wrap headers in `NS_ASSUME_NONNULL_BEGIN` / `NS_ASSUME_NONNULL_END`; mark exceptions with `nullable`.
- Use lightweight generics (`NSArray<NSString *> *`) so Swift gets `[String]`, not `[Any]`.
- Use `NS_SWIFT_NAME` where it demonstrates how Objective-C names map to Swift.
- Delegate properties must be `weak`.
- Use the `DB` prefix for all Objective-C classes and protocols.
- Later exercises (only when the developer is ready): `NS_ENUM`, and `NSError **` mapping to Swift `throws`.

Foundation types to demonstrate, **introduced gradually, one at a time**:

```text
NSString ↔ String
NSInteger ↔ Int
NSArray ↔ Array
NSDictionary ↔ Dictionary
nullability ↔ Optional
```

Swift: follow the Swift API Design Guidelines. Prefer `final` classes and small types.

---

## State Management

- Use `@Observable` (Observation framework) for the ViewModel.
- Explain why it is chosen the first time it appears (less boilerplate than `ObservableObject` / `@Published`).
- Do **not** introduce Combine or UIKit unless a specific learning exercise requires it. The UI stays SwiftUI.
- Do **not** add persistence (Core Data, SwiftData, SQLite) or networking. The app is fully local.

---

## Learning-First Rules

### Explain before you build

Before introducing a significant concept (bridging header, nullability, delegate, etc.), briefly cover:

1. **What** it is
2. **Why** it's needed
3. **Which language** it belongs to
4. **How** it communicates with the other language
5. **Where** it's used in this project

Then show a small example, then implement. Keep explanations short and include a flow diagram, for example:

```text
DBTextUtility.h → Bridging Header → Swift
```

For significant architectural changes: explain what changes, why, whether it belongs to Swift / Objective-C / SwiftUI, show the flow, then implement.

### Don't assume Objective-C knowledge

The developer is learning Objective-C. Explain syntax such as `@interface`, `@implementation`, `NSString *`, and message-sending the first time it appears.

### Don't auto-complete learning exercises

If a task is clearly a learning exercise, use: **Explain → small example → let the developer digest → implement.** If the developer says "implement it" or "just do it", skip the pre-explanation and implement, but still add concept-focused comments.

### Bridging header explanation is mandatory

When introducing or changing the bridging header or any interop build setting, explain what was changed and why. Never configure interop silently.

### Comments

Comment to explain concepts, not syntax.

Good:

```swift
// DBTextUtility is implemented in Objective-C.
// The bridging header exposes its public interface to Swift.
let utility = DBTextUtility()
```

Bad: `// Create utility`

---

## Delegate Exercise (Objective-C → Swift)

This is a key learning objective. Do not replace it with a closure unless there is a specific reason and the developer agrees.

Spec:

- Define an Objective-C protocol `DBTextUtilityDelegate` with events such as `didStartProcessing`, `didUpdateProgress:`, and `didFinishProcessing:` (adjust with the developer).
- `DBTextUtility` holds a `weak` delegate.
- The **Swift service** conforms to the protocol and forwards events to the ViewModel.
- **Threading:** Determine which thread callbacks arrive on. Ensure ViewModel state is updated on the main actor (`@MainActor`). Explain this to the developer.
- Target flow:

```text
Objective-C → delegate callback → Swift Service → ViewModel → SwiftUI
```

- Watch for retain cycles (`weak` delegate in Objective-C; `[weak self]` where needed in Swift).

---

## Testing (XCTest)

Tests must include:

- **Swift:** ViewModel behavior, service behavior, `ProcessingResult` creation.
- **Objective-C:** uppercase, character count, string reversal. State whether each test is written in Objective-C or in Swift calling Objective-C; at least one should make the boundary explicit.
- **Interop:** at least one test proving Swift can call the Objective-C implementation, with a comment marking the language boundary.
- **Delegate:** verify callbacks using `XCTestExpectation` or a mock delegate.

---

## Code Quality

Prefer: small classes and methods, clear naming, explicit responsibilities, simple dependency flow, native Apple APIs, readable code over clever code. Readability matters more than fewer lines.

Avoid: over-engineering, premature abstraction, generic utility frameworks, excessive protocols, unnecessary dependency injection.

---

## Development Phases

Complete **one phase at a time**. At the end of each phase: run build/tests, summarize what changed and the flow, and wait for confirmation.

| Phase | Work | Done when |
|---|---|---|
| 1. Objective-C | Create `DBTextUtility.h/.m` (with nullability annotations) | It compiles and behaves correctly on its own |
| 2. Swift ↔ Objective-C | Configure bridging header; call Objective-C from Swift | A Swift call to `DBTextUtility` returns the expected value |
| 3. Swift architecture | `ProcessingResult`, `TextProcessingService`, `DevBridgeViewModel` | The service calls Objective-C; the ViewModel calls the service |
| 4. SwiftUI | Build the UI | Typing text and tapping a button shows a result via ViewModel → Service → Objective-C |
| 5. XCTest | Swift, Objective-C, and interop tests | All tests pass |
| 6. Delegate | Objective-C protocol/delegate back into Swift | Callbacks update ViewModel state and the UI reacts |
| 7. Review | Trace the full flow with the developer | The developer can explain every step |

---

## Out of Scope

Localization, accessibility polish, CI, analytics, animations beyond basic SwiftUI, and anything on the "no" lists above.

---

## Definition of Done

- SwiftUI UI works and reacts to Swift state changes.
- MVVM is implemented as described.
- The Objective-C utility works; Swift can call it.
- Objective-C communicates back to Swift via a delegate.
- XCTest covers Swift, Objective-C, interop, and the delegate.
- No unnecessary dependencies; no Git changes made by the agent.
- The developer understands and can explain the complete communication flow.
