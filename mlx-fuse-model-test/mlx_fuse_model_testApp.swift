import SwiftUI

@main
struct mlx_fuse_model_testApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // One window, sized so the diff and the answer fit without resizing.
        .windowResizability(.contentMinSize)
    }
}
