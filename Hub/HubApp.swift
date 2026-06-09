import SwiftUI

@main
struct HubApp: App {
    @UIApplicationDelegateAdaptor(BBBApplicationDelegate.self) private var applicationDelegate
    @StateObject private var store = TaskStore()

    var body: some Scene {
        WindowGroup {
            HubRootView()
                .environmentObject(store)
                .preferredColorScheme(store.colorScheme)
                .environment(\.hubLanguage, store.appLanguage)
                .environment(\.locale, store.appLanguage.locale)
                .task {
                    await store.setupOnLaunch()
                }
        }
    }
}
