import Foundation
import Observation

// MARK: - SleepTimerService

typealias SleepTimerSleepOperation = @Sendable (Duration) async throws -> Void
typealias SleepTimerExpiryAction = @MainActor @Sendable () async -> Void

/// Owns the app-wide, runtime-only countdown that pauses active playback.
@MainActor
@Observable
final class SleepTimerService {
    static let supportedMinutes = 1 ... 720

    private(set) var deadline: Date?

    var isActive: Bool {
        self.deadline != nil
    }

    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let sleep: SleepTimerSleepOperation
    @ObservationIgnored private let onExpire: SleepTimerExpiryAction
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var generation = 0

    init(
        now: @escaping @Sendable () -> Date = Date.init,
        sleep: @escaping SleepTimerSleepOperation = { try await Task.sleep(for: $0) },
        onExpire: @escaping SleepTimerExpiryAction
    ) {
        self.now = now
        self.sleep = sleep
        self.onExpire = onExpire
    }

    @discardableResult
    func start(minutes: Int) -> Bool {
        let multiplication = minutes.multipliedReportingOverflow(by: 60)
        guard Self.supportedMinutes.contains(minutes), !multiplication.overflow else {
            return false
        }

        self.cancel()
        self.generation += 1
        let generation = self.generation
        let deadline = self.now().addingTimeInterval(TimeInterval(multiplication.partialValue))
        self.deadline = deadline
        self.task = Task { [weak self] in
            await self?.waitForExpiry(generation: generation, deadline: deadline)
        }
        return true
    }

    func cancel() {
        self.task?.cancel()
        self.task = nil
        self.generation += 1
        self.deadline = nil
    }

    private func waitForExpiry(generation: Int, deadline: Date) async {
        while !Task.isCancelled {
            let remaining = deadline.timeIntervalSince(self.now())
            guard remaining > 0 else { break }

            do {
                try await self.sleep(.seconds(remaining))
            } catch {
                return
            }
        }

        guard !Task.isCancelled, generation == self.generation, self.deadline == deadline else { return }
        self.task = nil
        self.deadline = nil
        await self.onExpire()
    }
}
