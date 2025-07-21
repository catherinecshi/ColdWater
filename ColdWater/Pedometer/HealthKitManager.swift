import Foundation
import HealthKit

class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var stepCount: Int = 0
    @Published var isAuthorized: Bool = false
    
    /// Request authorization to access HealthKit data
    func requestHealthKitAuthorization() async {
        // Check if HealthKit is available on this device
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
        
        // Define the health data types we want to read
        guard let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            print("Step count type is not available")
            return
        }
        
        let healthKitTypesToRead: Set<HKObjectType> = [stepCountType]
        
        // Request authorization
        do {
            try await healthStore.requestAuthorization(toShare: [], read: healthKitTypesToRead)
            await MainActor.run {
                self.isAuthorized = true
            }
            print("HealthKit authorization successful")
        } catch {
            print("HealthKit authorization failed: \(error.localizedDescription)")
        }
    }
    
    /// Fetch today's step count from HealthKit
    func fetchStepCount() async {
        guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            print("Step count type is not available")
            return
        }
        
        // Set up date range for today
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )
        
        // Create statistics query to get cumulative step count for today
        let query = HKStatisticsQuery(
            quantityType: stepCountType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                print("Error fetching step count: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            let stepCount = Int(sum.doubleValue(for: HKUnit.count()))
            
            DispatchQueue.main.async {
                self.stepCount = stepCount
            }
        }
        
        healthStore.execute(query)
    }
    
    /// Check authorization status for step count
    func checkAuthorizationStatus() {
        guard let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            return
        }
        
        let status = healthStore.authorizationStatus(for: stepCountType)
        
        switch status {
        case .notDetermined:
            print("HealthKit authorization not determined")
            isAuthorized = false
        case .sharingDenied:
            print("HealthKit authorization denied")
            isAuthorized = false
        case .sharingAuthorized:
            print("HealthKit authorization granted")
            isAuthorized = true
        @unknown default:
            print("HealthKit authorization unknown status")
            isAuthorized = false
        }
    }
    
    /// Set up real-time step count monitoring
    func startStepCountObserver() {
        guard let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            return
        }
        
        // Create observer query for real-time updates
        let query = HKObserverQuery(sampleType: stepCountType, predicate: nil) { [weak self] _, _, error in
            if let error = error {
                print("Observer query error: \(error.localizedDescription)")
                return
            }
            
            // Fetch updated step count when new data is available
            Task {
                await self?.fetchStepCount()
            }
        }
        
        healthStore.execute(query)
        
        // Enable background delivery for step count updates
        healthStore.enableBackgroundDelivery(for: stepCountType, frequency: .immediate) { success, error in
            if let error = error {
                print("Failed to enable background delivery: \(error.localizedDescription)")
            } else if success {
                print("Background delivery enabled for step count")
            }
        }
    }
}
