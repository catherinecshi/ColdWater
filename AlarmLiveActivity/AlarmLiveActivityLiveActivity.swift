//
//  AlarmLiveActivityLiveActivity.swift
//  AlarmLiveActivity
//
//  Created by Shi Catherine on 8/23/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct AlarmLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct AlarmLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmLiveActivityAttributes.self) { context in
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

extension AlarmLiveActivityAttributes {
    fileprivate static var preview: AlarmLiveActivityAttributes {
        AlarmLiveActivityAttributes(name: "World")
    }
}

extension AlarmLiveActivityAttributes.ContentState {
    fileprivate static var smiley: AlarmLiveActivityAttributes.ContentState {
        AlarmLiveActivityAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: AlarmLiveActivityAttributes.ContentState {
         AlarmLiveActivityAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: AlarmLiveActivityAttributes.preview) {
   AlarmLiveActivityLiveActivity()
} contentStates: {
    AlarmLiveActivityAttributes.ContentState.smiley
    AlarmLiveActivityAttributes.ContentState.starEyes
}
