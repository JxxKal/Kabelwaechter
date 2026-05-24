//
//  Kabelwaechter_iOSApp.swift
//  Kabelwaechter iOS
//
//  Created by Jan Kaluza on 24.05.26.
//

import SwiftUI
import SwiftData
import KabelwaechterCore

@main
struct Kabelwaechter_iOSApp: App {
    init() {
        print("Kabelwaechter iOS startet — Bundle-Prefix: \(KabelwaechterConstants.BundleIdentifiers.prefix)")
    }

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
