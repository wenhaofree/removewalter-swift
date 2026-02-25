//
//  removewalter_swiftApp.swift
//  removewalter-swift
//
//  Created by wenhao on 2026/2/25.
//

import SwiftUI
import SwiftData

@main
struct removewalter_swiftApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            HistoryRecord.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
