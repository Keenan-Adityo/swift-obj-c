import SwiftUI

@main struct MyApp: App {
    init() {
        // Phase 2 only: runs the Objective-C bridge check at launch so its
        // output shows up in the system log. Phase 3 replaces this with the
        // ViewModel -> Service flow.
        BridgeScratchCheck.run()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
