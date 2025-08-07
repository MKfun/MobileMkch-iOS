//
//  MobileMkchApp.swift
//  MobileMkch
//
//  Created by Platon on 06.08.2025.
//

import SwiftUI

@main
struct MobileMkchApp: App {
    @StateObject private var settings = Settings()
    @StateObject private var apiClient = APIClient()
    @StateObject private var crashHandler = CrashHandler.shared
    @StateObject private var notificationManager = NotificationManager.shared
    
    private func setupBackgroundTasks() {
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            let backgroundTaskIdentifier = "\(bundleIdentifier).backgroundrefresh"
            UserDefaults.standard.set(backgroundTaskIdentifier, forKey: "BackgroundTaskIdentifier")
            print("Background task identifier: \(backgroundTaskIdentifier)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if crashHandler.hasCrashed {
                    CrashScreen()
                } else {
                    MainTabView()
                        .environmentObject(settings)
                        .environmentObject(apiClient)
                        .environmentObject(notificationManager)
                        .preferredColorScheme(settings.theme == "dark" ? .dark : .light)
                }
            }
            .onAppear {
                BackgroundTaskManager.shared.registerBackgroundTasks()
                setupBackgroundTasks()
            }
        }
    }
}
