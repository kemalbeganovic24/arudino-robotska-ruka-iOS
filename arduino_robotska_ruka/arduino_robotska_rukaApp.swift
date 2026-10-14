//
//  arduino_robotska_rukaApp.swift
//  arduino_robotska_ruka
//
//  Created by Kemal Beganovic on 10. 8. 2026..
//

import SwiftUI
import SwiftData

@main
struct arduino_robotska_rukaApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
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
