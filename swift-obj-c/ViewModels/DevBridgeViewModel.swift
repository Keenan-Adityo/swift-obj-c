//
//  DevBridgeViewModel.swift
//  swift-obj-c
//
//  The screen's state, in Swift.
//
//  Look at what this file does NOT contain: no Objective-C type, no NSError,
//  no Objective-C import. It depends on the `TextProcessing` protocol only, so
//  the compiler enforces the layer rule rather than relying on memory.
//

import Foundation
import Observation

/// `@MainActor`: this object is UI state, and UI state may only be touched
/// on the main actor. SwiftUI guarantees its views run there too.
///
/// `@Observable` (Observation framework, iOS 17+) instead of
/// `ObservableObject` + `@Published`: one attribute instead of one per
/// property, no Combine, and SwiftUI redraws only the views that actually
/// read a property that changed.
@MainActor
@Observable
final class DevBridgeViewModel {

    /// Raw text field content — the only property the View writes to.
    var inputText = ""

    /// Set on success, cleared on failure.
    private(set) var result: ProcessingResult?

    /// Set on failure, cleared on success. Already user-readable: Objective-C
    /// errors were translated into `TextProcessingError` down in the service,
    /// so `localizedDescription` is safe to show.
    private(set) var errorMessage: String?

    /// Injected so tests can substitute a mock. The protocol is the
    /// ViewModel's entire view of the world below it.
    private let service: TextProcessing

    init(service: TextProcessing = TextProcessingService()) {
        self.service = service
    }

    /// FR-06: empty or whitespace-only input disables the button instead of
    /// reaching the service, so nothing downstream can crash on it.
    var canProcess: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The single entry point the View calls.
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
