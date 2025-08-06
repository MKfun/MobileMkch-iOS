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
    
    var body: some Scene {
        WindowGroup {
            Group {
                if crashHandler.hasCrashed {
                    CrashScreen()
                } else {
                    NavigationView {
                        BoardsView()
                            .environmentObject(settings)
                            .environmentObject(apiClient)
                    }
                    .preferredColorScheme(settings.theme == "dark" ? .dark : .light)
                }
            }
        }
    }
}
