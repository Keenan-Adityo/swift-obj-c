//
//  ContentView.swift
//  swift-obj-c
//
//  The SwiftUI layer. It reads state from the ViewModel and sends user
//  actions back to it — nothing else. Note the absence of Objective-C types
//  and of business logic: this file only decides how state is displayed.
//

import SwiftUI
import Playgrounds

struct ContentView: View {

    /// `@State` + `@Observable`: SwiftUI creates and owns one ViewModel for
    /// this view, then re-renders only the parts of `body` whose properties
    /// changed. Writing `$viewModel.inputText` binds the text field straight
    /// to it — no manual "update the label" code anywhere.
    @State private var viewModel = DevBridgeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    LabeledSection(title: "Input") {
                        // The placeholder doubles as the spoken label, and the
                        // explicit accessibilityLabel keeps it after typing.
                        TextField("Enter text", text: $viewModel.inputText)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Enter text")
                    }

                    processButton

                    LabeledSection(title: "Result") {
                        resultContent
                    }

                    messageSection

                    LabeledSection(title: "Architecture") {
                        architectureDiagram
                    }
                }
                .padding()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Sections

    /// Header required by PRD §7: title plus subtitle.
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DevBridge")
                .font(.largeTitle.bold())
            Text("Obj-C + Swift + SwiftUI")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// FR-02 / FR-06: disabled whenever input is empty or whitespace-only, so
    /// invalid input can never reach the service.
    private var processButton: some View {
        Button {
            viewModel.processText()
        } label: {
            Text("Process Text")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!viewModel.canProcess)
        .accessibilityLabel("Process Text")
        .accessibilityHint("Runs the Objective-C text utility")
    }

    /// FR-04 / FR-05: every value in a labelled row, with both length numbers
    /// side by side and attributed to the language that produced them.
    @ViewBuilder
    private var resultContent: some View {
        if let result = viewModel.result {
            resultRow("Original", result.originalText)
            resultRow("Uppercase", result.uppercaseText)
            resultRow("Reversed", result.reversedText)
            resultRow("UTF-16 units (Obj-C)", String(result.utf16Length))
            resultRow("Characters (Swift)", String(result.characterCount))
        } else {
            // FR-06 empty state — never a crash, always an explanation.
            Text("No result yet. Enter some text and tap Process Text.")
                .foregroundStyle(.secondary)
        }
    }

    /// One row = one accessibility element, so VoiceOver says
    /// "Uppercase, HELLO SWIFT" instead of two disconnected fragments.
    private func resultRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospaced())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// PRD §7 item 5: inline error, or a hint when there is nothing to do.
    /// The error text is already user-readable — the service translated the
    /// Objective-C NSError into TextProcessingError before it got here.
    @ViewBuilder
    private var messageSection: some View {
        if let errorMessage = viewModel.errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                .font(.callout)
                .foregroundStyle(.red)
                .accessibilityElement(children: .combine)
        } else if !viewModel.canProcess {
            Text("Enter text to enable processing.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
        }
    }

    /// FR-08: the layers, top to bottom.
    private var architectureDiagram: some View {
        VStack(spacing: 2) {
            Text("SwiftUI")
            Image(systemName: "arrow.down")
            Text("Swift")
            Image(systemName: "arrow.down")
            Text("Objective-C")
        }
        .font(.callout.weight(.medium))
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("SwiftUI, then Swift, then Objective-C")
    }

}

/// Groups a heading with its content and marks the heading for VoiceOver.
private struct LabeledSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            content
        }
    }
}

#Preview {
    ContentView()
}

#Playground {
    _ = 1 + 2
}
