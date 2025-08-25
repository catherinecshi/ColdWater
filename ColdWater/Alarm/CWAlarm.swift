import Foundation
import SwiftUI
import AlarmKit

@available(iOS 26.0, *)
@dynamicMemberLookup
struct CWAlarm: Codable, Identifiable, Sendable {
    var alarm: Alarm {
        didSet {
            self.updatePresentationState(oldAlarm: oldValue)
        }
    }
    
    var metadata: CWAlarmMetadata
    var presentationMode: AlarmPresentationState.Mode? = nil
    
    var id: UUID {
        alarm.id
    }
    
    init(alarm: Alarm, metadata: CWAlarmMetadata, isRecent: Bool = false) {
        self.alarm = alarm
        self.metadata = metadata
        if !isRecent {
            self.updatePresentationState(oldAlarm: nil)
        }
    }
    
    subscript<T>(dynamicMember keyPath: KeyPath<CWAlarmMetadata, T>) -> T {
        return metadata[keyPath: keyPath]
    }
    
    subscript<T>(dynamicMember keyPath: KeyPath<Alarm, T>) -> T {
        return alarm[keyPath: keyPath]
    }
    
    // MARK: - ColdWater Specific Properties
    var isWakeUpAlarm: Bool {
        metadata.wakeUpMethod != nil
    }
    
    var requiresStepsCheck: Bool {
        metadata.wakeUpMethod == .steps && metadata.stepGoal != nil
    }
    
    var requiresLocationCheck: Bool {
        metadata.wakeUpMethod == .location && metadata.location != nil
    }
    
    var hasMotivationConsequence: Bool {
        metadata.motivationMethod != nil && metadata.motivationMethod != .none
    }
    
    // Copy the sophisticated presentation state logic from ItsukiAlarm
    mutating private func updatePresentationState(oldAlarm: Alarm?) {
        var newMode: AlarmPresentationState.Mode? = self.presentationMode
        let now = Date()
        
        defer {
            self.presentationMode = newMode
        }
        
        guard let oldAlarm else {
            switch self.alarm.state {
            case .alerting:
                if let time = now.time {
                    newMode = .alert(.init(time: time))
                } else {
                    newMode = nil
                }
                return
                
            case .scheduled:
                guard let schedule = alarm.schedule else { return }
                let time: Alarm.Schedule.Relative.Time = switch schedule {
                case .relative(let relative):
                    relative.time
                case .fixed(let date):
                    Alarm.Schedule.Relative.Time(hour: date.time?.hour ?? 0, minute: date.time?.minute ?? 0)
                @unknown default:
                    Alarm.Schedule.Relative.Time(hour: 0, minute: 0)
                }
                newMode = .alert(.init(time: time))
                return
                
            case .countdown:
                guard let duration = timerDuration else {
                    return 
                }
                newMode = .countdown(.init(
                    totalCountdownDuration: duration,
                    previouslyElapsedDuration: 0,
                    startDate: now,
                    fireDate: self.metadata.createdAt)
                )
                return
                
            case .paused:
                guard let duration = timerDuration else {
                    return 
                }
                newMode = .paused(.init(totalCountdownDuration: duration, previouslyElapsedDuration: 0))
                return
                
            @unknown default:
                return
            }
        }
        
        if oldAlarm.state == alarm.state && oldAlarm.id == alarm.id &&
           oldAlarm.countdownDuration == alarm.countdownDuration &&
           oldAlarm.schedule == alarm.schedule {
            return
        }
        
        switch (oldAlarm.state, alarm.state) {
        case (.scheduled, .countdown):
            guard let duration = timerDuration else { return }
            newMode = .countdown(.init(
                totalCountdownDuration: duration,
                previouslyElapsedDuration: 0,
                startDate: now,
                fireDate: self.metadata.createdAt)
            )
            
        case (.countdown, .paused):
            guard case .countdown(let countdown) = self.presentationMode else { return }
            let previousElapsed = now.timeIntervalSince(countdown.startDate) + countdown.previouslyElapsedDuration
            newMode = .paused(.init(totalCountdownDuration: countdown.totalCountdownDuration, previouslyElapsedDuration: previousElapsed))
            
        case (.paused, .countdown):
            guard case .paused(let pause) = self.presentationMode else { return }
            newMode = .countdown(.init(
                totalCountdownDuration: pause.totalCountdownDuration,
                previouslyElapsedDuration: pause.previouslyElapsedDuration,
                startDate: now,
                fireDate: self.metadata.createdAt)
            )
            
        case (_, .scheduled):
            guard let schedule = alarm.schedule else { return }
            let time: Alarm.Schedule.Relative.Time = switch schedule {
            case .relative(let relative):
                relative.time
            case .fixed(let date):
                Alarm.Schedule.Relative.Time(hour: date.time?.hour ?? 0, minute: date.time?.minute ?? 0)
            default:
                Alarm.Schedule.Relative.Time(hour: 0, minute: 0)
            }
            newMode = .alert(.init(time: time))
            
        case (_, .alerting):
            if let time = now.time {
                newMode = .alert(.init(time: time))
            } else {
                newMode = nil
            }
            
        default:
            return
        }
    }
}

// MARK: - Extensions
@available(iOS 26.0, *)
extension CWAlarm {
    var isOneShot: Bool {
        guard let schedule = alarm.schedule else { return true }
        
        switch schedule {
        case .fixed(_):
            return true
        case .relative(let relative):
            switch relative.repeats {
            case .never:
                return true
            case .weekly(let weekdays):
                return weekdays.isEmpty
            @unknown default:
                return true
            }
        @unknown default:
            return true
        }
    }
    
    var timerDuration: TimeInterval? {
        guard let countdownDuration = alarm.countdownDuration else { return nil }
        return countdownDuration.preAlert
    }
}

@available(iOS 26.0, *)
extension AlarmButton {
    static var snoozeButton: Self {
        AlarmButton(text: "Snooze", textColor: .white, systemImageName: "moon.zzz")
    }
    
    static var pauseButton: Self {
        AlarmButton(text: "Pause", textColor: .blue, systemImageName: "pause.fill")
    }
    
    static var resumeButton: Self {
        AlarmButton(text: "Resume", textColor: .blue, systemImageName: "play.fill")
    }
    
    static var stopButton: Self {
        AlarmButton(text: "Stop", textColor: .white, systemImageName: "xmark")
    }
}
