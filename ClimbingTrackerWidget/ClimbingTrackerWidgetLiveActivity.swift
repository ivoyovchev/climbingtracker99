//
//  ClimbingTrackerWidgetLiveActivity.swift
//  ClimbingTrackerWidget
//
//  Created by Ivo Yovchev on 17/04/2025.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct ClimbingTrackerWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct ClimbingTrackerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClimbingTrackerWidgetAttributes.self) { context in
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

extension ClimbingTrackerWidgetAttributes {
    fileprivate static var preview: ClimbingTrackerWidgetAttributes {
        ClimbingTrackerWidgetAttributes(name: "World")
    }
}

extension ClimbingTrackerWidgetAttributes.ContentState {
    fileprivate static var smiley: ClimbingTrackerWidgetAttributes.ContentState {
        ClimbingTrackerWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: ClimbingTrackerWidgetAttributes.ContentState {
         ClimbingTrackerWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: ClimbingTrackerWidgetAttributes.preview) {
   ClimbingTrackerWidgetLiveActivity()
} contentStates: {
    ClimbingTrackerWidgetAttributes.ContentState.smiley
    ClimbingTrackerWidgetAttributes.ContentState.starEyes
}
