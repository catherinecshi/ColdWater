import SwiftUI
  import AlarmKit
  import AppIntents

struct AlarmControls: View {
    var presentation: AlarmPresentation
    var state: AlarmPresentationState

    var body: some View {
        let id = state.alarmID

        HStack(spacing: 8) {
            switch state.mode {
            case .countdown(_):
                if let pauseButton = presentation.countdown?.pauseButton {
                    Button(intent: PauseIntent(alarmID: id)) {
                        buttonImage(pauseButton)
                    }
                    .tint(pauseButton.textColor.opacity(0.3))
                }

            case .paused(_):
                if let resumeButton = presentation.paused?.resumeButton {
                    Button(intent: ResumeIntent(alarmID: id)) {
                        buttonImage(resumeButton)
                    }
                    .tint(resumeButton.textColor.opacity(0.3))
              }

            case .alert(_):
                if let secondaryButton = presentation.alert.secondaryButton {
                    Button(intent: RepeatIntent(alarmID: id)) {
                        buttonImage(secondaryButton)
                            .foregroundStyle(Color.blue)
                    }
                    .tint(Color.blue.opacity(0.3))
                }

            default:
                EmptyView()
            }

            Button(intent: StopIntent(alarmID: id)) {
                buttonImage(presentation.alert.stopButton)
                    .foregroundStyle(presentation.alert.stopButton.textColor)
            }
            .tint(.gray.opacity(0.3))
        }
    }

    private func buttonImage(_ alarmButton: AlarmButton) -> some View {
        Image(systemName: alarmButton.systemImageName)
            .foregroundStyle(alarmButton.textColor)
            .font(.system(size: 20))
            .fontWeight(.bold)
            .frame(width: 20, height: 20)
            .padding(.all, 4)
        }
}
