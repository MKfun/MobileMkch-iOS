//
//  FavoritesWidgetBundle.swift
//  FavoritesWidget
//
//  Created by Platon on 08.08.2025.
//

import WidgetKit
import SwiftUI
import ActivityKit

@main
struct FavoritesWidgetBundle: WidgetBundle {
    var body: some Widget {
        FavoritesWidget()
        if #available(iOS 16.1, *) {
            ThreadLiveActivity()
        }
    }
}
