import Foundation
import HealthKit

final class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    
    private init() {}
    
    var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    
    // Returns .sharingAuthorized/.sharingDenied/.notDetermined for a type
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        healthStore.authorizationStatus(for: type)
    }
    
    // MARK: - Authorization
    func requestAuthorization() async throws {
        guard isHealthDataAvailable else { return }
        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }
    
    // MARK: - Weight
    func fetchBodyMassSamples(from startDate: Date, to endDate: Date) async throws -> [(date: Date, kg: Double)] {
        let type = HKObjectType.quantityType(forIdentifier: .bodyMass)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: sort) { _, samples, error in
                if let error = error { return continuation.resume(throwing: error) }
                let unit = HKUnit.gramUnit(with: .kilo)
                let results: [(Date, Double)] = (samples as? [HKQuantitySample] ?? []).map {
                    ($0.startDate, $0.quantity.doubleValue(for: unit))
                }
                continuation.resume(returning: results)
            }
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - Sleep
    func fetchSleepAnalysis(from startDate: Date, to endDate: Date) async throws -> [(start: Date, end: Date, value: Int)] {
        let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: sort) { _, samples, error in
                if let error = error { return continuation.resume(throwing: error) }
                let results: [(Date, Date, Int)] = (samples as? [HKCategorySample] ?? []).map {
                    ($0.startDate, $0.endDate, $0.value)
                }
                continuation.resume(returning: results)
            }
            self.healthStore.execute(query)
        }
    }
    
    // Fallback: fetch a long-range window if a short window returned nothing
    func fetchSleepFallbackIfEmpty(primaryStart: Date, end: Date, monthsBack: Int = 12) async throws -> [(start: Date, end: Date, value: Int)] {
        let primary = try await fetchSleepAnalysis(from: primaryStart, to: end)
        if !primary.isEmpty { return primary }
        let longStart = Calendar.current.date(byAdding: .month, value: -monthsBack, to: end) ?? Date.distantPast
        return try await fetchSleepAnalysis(from: longStart, to: end)
    }
    
    // MARK: - Heart Rate (latest)
    func fetchLatestHeartRate() async throws -> (date: Date, bpm: Double)? {
        let type = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: sort) { _, samples, error in
                if let error = error { return continuation.resume(throwing: error) }
                guard let sample = (samples as? [HKQuantitySample])?.first else { return continuation.resume(returning: nil) }
                let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
                continuation.resume(returning: (sample.startDate, sample.quantity.doubleValue(for: unit)))
            }
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - Heart Rate samples
    func fetchHeartRateSamples(from startDate: Date, to endDate: Date) async throws -> [(date: Date, bpm: Double)] {
        let type = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: sort) { _, samples, error in
                if let error = error { return continuation.resume(throwing: error) }
                let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
                let results: [(Date, Double)] = (samples as? [HKQuantitySample] ?? []).map { ($0.startDate, $0.quantity.doubleValue(for: unit)) }
                continuation.resume(returning: results)
            }
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - Active Energy (sum for interval)
    func fetchActiveEnergySum(from startDate: Date, to endDate: Date) async throws -> Double {
        let type = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: sort) { _, samples, error in
                if let error = error { return continuation.resume(throwing: error) }
                let unit = HKUnit.kilocalorie()
                let total = (samples as? [HKQuantitySample] ?? []).reduce(0.0) { acc, s in
                    acc + s.quantity.doubleValue(for: unit)
                }
                continuation.resume(returning: total)
            }
            self.healthStore.execute(query)
        }
    }
}


