import SwiftUI
import AlarmKit
import AVFoundation
import AudioToolbox

@available(iOS 26.0, *)
struct ForegroundAlarmView: View {
    let alarm: CWAlarm
    @ObservedObject var alarmManager = CWAlarmManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var audioPlayer: AVAudioPlayer?
    @State private var currentTime = Date()
    @State private var timer: Timer?
    @State private var shouldShowForegroundUI = true
    
    // Computed property to get current alarm state
    private var currentAlarmState: Alarm.State {
        if let currentAlarm = alarmManager.activeAlarms.first(where: { $0.id == alarm.id }) {
            return currentAlarm.alarm.state
        }
        return alarm.alarm.state
    }
    
    var body: some View {
        Group {
            if shouldShowForegroundUI && scenePhase == .active {
                foregroundAlarmContent
            } else {
                // App is not in foreground, dismiss this view and let system handle
                Color.clear
                    .onAppear {
                        dismiss()
                    }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }
    
    @ViewBuilder
    private var foregroundAlarmContent: some View {
        ZStack {
            // Full-screen dark background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Current time display
                Text(currentTime, style: .time)
                    .font(.system(size: 80, weight: .thin, design: .default))
                    .foregroundColor(.white)
                    .monospacedDigit()
                
                Spacer()
                
                // Alarm title
                Text(alarm.metadata.title)
                    .font(.title)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                // Alarm state-specific content
                alarmStateContent
                
                Spacer()
                
                // Action buttons
                actionButtons
                
                Spacer()
            }
        }
        .onAppear {
            startTimer()
            playAlarmSound()
            startHaptics()
        }
        .onDisappear {
            stopTimer()
            stopAlarmSound()
        }
        .preferredColorScheme(.dark)
    }
    
    @ViewBuilder
    private var alarmStateContent: some View {
        switch currentAlarmState {
        case .countdown:
            // Show countdown timer if available
            if let currentAlarm = alarmManager.activeAlarms.first(where: { $0.id == alarm.id }),
               let countdownDuration = currentAlarm.alarm.countdownDuration {
                CountdownDisplay(countdownDuration: countdownDuration, alarmID: alarm.id)
            } else if let countdownDuration = alarm.alarm.countdownDuration {
                CountdownDisplay(countdownDuration: countdownDuration, alarmID: alarm.id)
            }
            
        case .paused:
            VStack(spacing: 16) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("Paused")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 60) {
            // Secondary button (snooze/motivation if available)
            if shouldShowSecondaryButton() {
                Button(action: handleSecondaryAction) {
                    VStack(spacing: 8) {
                        Image(systemName: getSecondaryButtonIcon())
                            .font(.system(size: 30))
                        
                        Text(getSecondaryButtonText())
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 80, height: 80)
                    .background(
                        Circle()
                            .fill(Color.blue.opacity(0.3))
                            .overlay(
                                Circle()
                                    .stroke(Color.blue, lineWidth: 2)
                            )
                    )
                }
            }
            
            // Stop button
            Button(action: handleStopAction) {
                VStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 35))
                    
                    Text("Stop")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(width: 100, height: 100)
                .background(
                    Circle()
                        .fill(.red)
                )
            }
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Helper Methods
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func playAlarmSound() {
        // Try to use system alarm sound, fallback to default
        guard let soundURL = Bundle.main.url(forResource: "alarm_sound", withExtension: "caf") ??
                             Bundle.main.url(forResource: "alarm_sound", withExtension: "mp3") else {
            // Use system sound as fallback
            AudioServicesPlaySystemSound(1005) // System alarm sound
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.volume = 1.0
            audioPlayer?.play()
        } catch {
            print("❌ [ALARM SOUND] Failed to play alarm sound: \(error)")
            // Fallback to system sound
            AudioServicesPlaySystemSound(1005)
        }
    }
    
    private func stopAlarmSound() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    private func startHaptics() {
        // Continuous haptic feedback while alarm is active
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // Schedule repeated haptics
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if alarmManager.showingForegroundAlarm?.id == alarm.id {
                startHaptics()
            }
        }
    }
    
    private func getSecondaryButtonIcon() -> String {
        if alarm.metadata.motivationMethod != .none {
            return "repeat"
        } else {
            return "zzz"
        }
    }
    
    private func getSecondaryButtonText() -> String {
        if alarm.metadata.motivationMethod != .none {
            return "Motivate"
        } else {
            return "Snooze"
        }
    }
    
    private func handleStopAction() {
        stopAlarmSound()
        
        do {
            try alarmManager.stopAlarm(alarm.id)
            alarmManager.showingForegroundAlarm = nil
            dismiss()
        } catch {
            print("❌ [FOREGROUND ALARM] Failed to stop alarm: \(error)")
        }
    }
    
    private func handleSecondaryAction() {
        if alarm.metadata.motivationMethod != .none {
            // Handle motivation method (steps, location, etc.)
            handleMotivationAction()
        } else {
            // Handle snooze
            handleSnoozeAction()
        }
    }
    
    private func handleMotivationAction() {
        // This would integrate with your existing motivation logic
        // Only attempt to pause if alarm has grace period and is in countdown state
        let alarmInstance = alarm.alarm
        
        if alarmInstance.state == .countdown && alarmInstance.countdownDuration != nil {
            do {
                try alarmManager.pauseAlarm(alarm.id)
            } catch {
                print("❌ [FOREGROUND ALARM] Failed to pause alarm for motivation: \(error)")
            }
        } else {
            print("⚠️ [FOREGROUND ALARM] Alarm doesn't support pausing - stopping instead")
            handleStopAction()
        }
    }
    
    private func handleSnoozeAction() {
        // Snooze the alarm (this would need to be implemented in AlarmManager)
        stopAlarmSound()
        alarmManager.showingForegroundAlarm = nil
        dismiss()
        
        // TODO: Schedule a new snooze alarm
        print("🔄 [FOREGROUND ALARM] Snooze functionality not yet implemented")
    }
    
    private func shouldShowSecondaryButton() -> Bool {
        // Don't show secondary button if alarm is alerting (countdown is over)
        if currentAlarmState == .alerting {
            return false
        }
        
        // Show secondary button if there's motivation method or if it's a snooze-capable alarm
        // and the alarm is still in countdown state
        return (alarm.metadata.motivationMethod != .none || alarm.metadata.gracePeriod != nil) &&
               currentAlarmState == .countdown
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        print("📱 [FOREGROUND ALARM] Scene phase changed to: \(newPhase)")
        
        switch newPhase {
        case .active:
            // App became active - this is good, keep showing foreground UI
            shouldShowForegroundUI = true
            
        case .inactive, .background:
            // App going to background - dismiss foreground UI and let system handle
            print("📱 [FOREGROUND ALARM] App going to background - dismissing foreground alarm UI")
            shouldShowForegroundUI = false
            stopAlarmSound()
            
        @unknown default:
            break
        }
    }
}

// MARK: - Supporting Views

@available(iOS 26.0, *)
struct CountdownDisplay: View {
    let countdownDuration: Alarm.CountdownDuration
    let alarmID: UUID
    @ObservedObject var alarmManager = CWAlarmManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "timer")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Complete your task")
                .font(.title3)
                .foregroundColor(.white)
            
            Text(formatTimeRemaining())
                .font(.system(size: 40, weight: .medium, design: .monospaced))
                .foregroundColor(.orange)
        }
    }
    
    private func formatTimeRemaining() -> String {
        let timeRemaining = alarmManager.getCountdownTimeRemaining(for: alarmID) ?? (countdownDuration.postAlert ?? 0)
        let totalSeconds = Int(timeRemaining)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "%d", seconds)
        }
    }
}
