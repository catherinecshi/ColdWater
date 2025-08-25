import SwiftUI
import AlarmKit

struct TimerDigitsView: View {
    var totalDuration: TimeInterval?
    var presentationMode: AlarmPresentationState.Mode?

    var body: some View {
        Group {
            switch presentationMode {
            case .countdown(let countdown):
                let remaining = countdown.totalCountdownDuration - countdown.previouslyElapsedDuration
                Text(timerInterval: countdown.startDate...countdown.startDate.addingTimeInterval(remaining), countsDown: true, showsHours: true)
                    
            case .paused(let pause):
                let remaining = pause.totalCountdownDuration - pause.previouslyElapsedDuration
                Text(remaining.formattedDigits)
                
            // alerting
            case .alert(_):
                Text(0.formattedDigits)
            
            case nil:
                if let totalDuration {
                    Text(totalDuration.formattedDigits)
                } else {
                    Text("--:--")
                }
            default:
                Text("--:--")
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)

    }
}

extension TimeInterval {
    var formattedDigits: String {
        let hours = Int(self) / 3600
        let minutes = Int(self) % 3600 / 60
        let seconds = Int(self) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
