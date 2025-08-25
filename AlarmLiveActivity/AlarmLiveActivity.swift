import ActivityKit
import WidgetKit
import SwiftUI
import AlarmKit
import AppIntents

struct AlarmLiveActivity: Widget {
    
    private func debugState(_ state: AlarmPresentationState, _ attributes: AlarmAttributes<CWAlarmMetadata>) {
        print("🟡 [WIDGET] ===== WIDGET RENDERING =====")
        print("🟡 [WIDGET] Dynamic Island rendering with state: \(state.mode)")
        print("🟡 [WIDGET] Alarm ID: \(state.alarmID)")
        print("🟡 [WIDGET] Metadata: \(attributes.metadata?.title ?? "nil")")
        print("🟡 [WIDGET] Tint Color: \(attributes.tintColor)")
        
        switch state.mode {
        case .alert(let alert):
            print("🟡 [WIDGET] Alert mode - time: \(alert.time)")
        case .countdown(let countdown):
            print("🟡 [WIDGET] Countdown mode - duration: \(countdown.totalCountdownDuration)")
        case .paused(let paused):
            print("🟡 [WIDGET] Paused mode - duration: \(paused.totalCountdownDuration)")
        default:
            print("🟡 [WIDGET] Other mode: \(state.mode)")
        }
        print("🟡 [WIDGET] ========================")
        
        // Also log to UserDefaults so main app can read it
        let defaults = UserDefaults(suiteName: "group.coldwateralarm")
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        let timestamp = formatter.string(from: Date())
        let logMessage = "[\(timestamp)] Widget rendered: \(state.mode)"
        defaults?.set(logMessage, forKey: "lastWidgetLog")
    }
    
  var body: some WidgetConfiguration {
      ActivityConfiguration<AlarmAttributes<CWAlarmMetadata>>(for: AlarmAttributes<CWAlarmMetadata>.self) { context in
          // Lock screen/banner UI goes here
          let attributes: AlarmAttributes<CWAlarmMetadata> = context.attributes
          let state: AlarmPresentationState = context.state

          VStack {
              HStack(alignment: .bottom, spacing: 8) {
                  AlarmControls(presentation: attributes.presentation, state: state)

                  HStack(alignment: .lastTextBaseline) {
                      let metadata = attributes.metadata ?? CWAlarmMetadata.defaultWakeUpMetadata
                      let title = metadata.title

                      Text("⏰ \(title.isEmpty ? "Alarm" : title)")
                          .font(.system(size: 16))
                          .layoutPriority(3)
                          .multilineTextAlignment(.trailing)
                          .lineLimit(1)
                          .frame(maxWidth: .infinity, alignment: .trailing)

                      TimerDigitsView(totalDuration: nil, presentationMode: state.mode)
                          .font(.system(size: 40, design: .rounded))
                          .multilineTextAlignment(.trailing)
                  }
                  .foregroundStyle(attributes.tintColor)
                  .layoutPriority(1)
                  .frame(maxWidth: .infinity, alignment: .trailing)
              }
          }
          .padding(.all, 16)
          .background(.black.opacity(0.95))
          .widgetURL(URL(string: "coldwater://alarm/\(state.alarmID)")!)
          .onAppear() {
              debugState(state, attributes)
          }

      } dynamicIsland: { context in
          let attributes: AlarmAttributes<CWAlarmMetadata> = context.attributes
          let state: AlarmPresentationState = context.state
          
          debugState(state, attributes)

          return DynamicIsland {
              DynamicIslandExpandedRegion(.leading) {
                  AlarmControls(presentation: attributes.presentation, state: state)
              }
              DynamicIslandExpandedRegion(.trailing) {
                  HStack(alignment: .lastTextBaseline) {
                      Text(attributes.metadata?.title ?? "Alarm")
                          .font(.system(size: 12))

                      TimerDigitsView(totalDuration: nil, presentationMode: state.mode)
                          .font(.system(size: 40, design: .rounded))
                          .frame(maxWidth: .infinity)
                  }
                  .foregroundStyle(attributes.tintColor)
                  .dynamicIsland(verticalPlacement: .belowIfTooWide)
              }
          } compactLeading: {
              // Debug: Force visible content with fallback
              Group {
                  if case .alert = state.mode {
                      Text("🔥")
                          .font(.system(size: 16))
                          .foregroundColor(.red)
                  } else {
                      progressView(tint: attributes.tintColor, mode: state.mode)
                  }
              }
              .padding(.all, 4)
          } compactTrailing: {
              // Debug: Force visible content with fallback
              Group {
                  TimerDigitsView(totalDuration: nil, presentationMode: state.mode)
              }
              .frame(maxWidth: 48)
              .foregroundStyle(.white)
          } minimal: {
              // Simplified minimal state - just solid red circle for debugging
              Circle()
                  .fill(Color.red)
                  .frame(width: 16, height: 16)
          }
          .keylineTint(attributes.tintColor)
          .widgetURL(URL(string: "coldwater://alarm/\(state.alarmID)")!)
      }
  }

  private func progressView(tint: Color, mode: AlarmPresentationState.Mode) -> some View {
      Group {
          switch mode {
          case .countdown(let countdown):
              let remaining = countdown.totalCountdownDuration - countdown.previouslyElapsedDuration
              ProgressView(
                  timerInterval: countdown.startDate...countdown.startDate.addingTimeInterval(remaining),
                  countsDown: true,
                  label: {},
                  currentValueLabel: {}
              )

          case .paused(let pausedState):
              let remaining = pausedState.totalCountdownDuration - pausedState.previouslyElapsedDuration
              ProgressView(
                  value: remaining,
                  total: pausedState.totalCountdownDuration,
                  label: { },
                  currentValueLabel: {}
              )

          default:
              ProgressView(value: 1, total: 1, label: {}, currentValueLabel: {})
          }
      }
      .progressViewStyle(.circular)
      .foregroundStyle(tint)
      .tint(tint)
      .labelsHidden()
  }
}
