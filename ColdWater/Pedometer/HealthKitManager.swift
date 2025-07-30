import Foundation
import HealthKit

enum TimeRange {
    case last7Days
    case last30Days
    
    func dateRange() -> (start: Date, end: Date) {
        let now = Date()
        let calendar = Calendar.current
        
        switch self {
        case .last7Days:
            let startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return (startDate, now)
        case .last30Days:
            let startDate = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            return (startDate, now)
        }
    }
}

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
    
    /// Check if we have step permission by attempting to read data (indirect method)
    func checkStepPermissionIndirectly() async -> Bool {
        print("🔍 Starting indirect permission check...")
        
        // Step 1: Quick check - any steps ever recorded?
        print("🔍 Step 1: Checking for any step data (limit: 1)...")
        if await hasAnyStepData(limit: 1) {
            print("✅ Step 1 SUCCESS: Found step data - permission confirmed!")
            await MainActor.run {
                self.isAuthorized = true
            }
            return true
        }
        print("❌ Step 1 FAILED: No step data found")
        
        // Step 2: Extended check - past 30 days
        print("🔍 Step 2: Checking past 30 days for step data...")
        if await hasAnyStepData(timeRange: .last30Days) {
            print("✅ Step 2 SUCCESS: Found step data in past 30 days - permission confirmed!")
            await MainActor.run {
                self.isAuthorized = true
            }
            return true
        }
        print("❌ Step 2 FAILED: No step data in past 30 days")
        
        // Step 3: Even more extended - past 7 days but query more samples
        print("🔍 Step 3: Checking past 7 days with extended limit (10 samples)...")
        if await hasAnyStepData(timeRange: .last7Days, limit: 10) {
            print("✅ Step 3 SUCCESS: Found step data in past 7 days - permission confirmed!")
            await MainActor.run {
                self.isAuthorized = true
            }
            return true
        }
        print("❌ Step 3 FAILED: No step data in past 7 days")
        
        print("🚫 All checks FAILED: Likely no permission or no step data exists")
        await MainActor.run {
            self.isAuthorized = false
        }
        return false
    }
    
    /// Helper function to check if any step data exists
    private func hasAnyStepData(limit: Int = 1) async -> Bool {
        guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            print("❌ Could not create stepCountType")
            return false
        }
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: stepCountType,
                predicate: nil,
                limit: limit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    print("❌ Error checking step data: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                    return
                }
                
                let hasAnyData = samples?.isEmpty == false
                let sampleCount = samples?.count ?? 0
                print("📊 Query result: Found \(sampleCount) samples, hasAnyData: \(hasAnyData)")
                
                continuation.resume(returning: hasAnyData)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Helper function to check if any step data exists within a time range
    private func hasAnyStepData(timeRange: TimeRange, limit: Int = 1) async -> Bool {
        guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            print("❌ Could not create stepCountType for time range query")
            return false
        }
        
        let (startDate, endDate) = timeRange.dateRange()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        print("📅 Querying from \(startDate) to \(endDate) with limit \(limit)")
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: stepCountType,
                predicate: predicate,
                limit: limit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    print("❌ Error checking step data for time range: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                    return
                }
                
                let hasAnyData = samples?.isEmpty == false
                let sampleCount = samples?.count ?? 0
                print("📊 Time range query result: Found \(sampleCount) samples, hasAnyData: \(hasAnyData)")
                
                continuation.resume(returning: hasAnyData)
            }
            
            healthStore.execute(query)
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
