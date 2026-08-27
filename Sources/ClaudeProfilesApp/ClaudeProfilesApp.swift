import SwiftUI

@main
struct ClaudeProfilesApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 620, minHeight: 460)
        }
        .defaultSize(width: 680, height: 520)
    }
}
