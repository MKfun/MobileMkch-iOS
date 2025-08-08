//
//  FavoritesWidgetLiveActivity.swift
//  FavoritesWidget
//
//  Created by Platon on 08.08.2025.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct FavoritesWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct FavoritesWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FavoritesWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension FavoritesWidgetAttributes {
    fileprivate static var preview: FavoritesWidgetAttributes {
        FavoritesWidgetAttributes(name: "World")
    }
}

extension FavoritesWidgetAttributes.ContentState {
    fileprivate static var smiley: FavoritesWidgetAttributes.ContentState {
        FavoritesWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: FavoritesWidgetAttributes.ContentState {
         FavoritesWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: FavoritesWidgetAttributes.preview) {
   FavoritesWidgetLiveActivity()
} contentStates: {
    FavoritesWidgetAttributes.ContentState.smiley
    FavoritesWidgetAttributes.ContentState.starEyes
}
