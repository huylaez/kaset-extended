import Foundation
import Testing
@testable import Kaset

@Suite("SleepTimerService", .serialized, .tags(.service), .timeLimit(.minutes(1)))
@MainActor
struct SleepTimerServiceTests {
    @Test("Starts inactive and accepts the supported duration bounds")
    func acceptsDurationBounds() async {
        let fixture = TimerFixture()

        #expect(!fixture.service.isActive)
        #expect(fixture.service.start(minutes: 1))
        #expect(fixture.service.isActive)
        fixture.service.cancel()
        #expect(fixture.service.start(minutes: 720))
    }

    @Test("Invalid duration does not replace an active timer")
    func invalidDurationPreservesTimer() {
        let fixture = TimerFixture()
        #expect(fixture.service.start(minutes: 15))
        let deadline = fixture.service.deadline

        #expect(!fixture.service.start(minutes: 0))
        #expect(!fixture.service.start(minutes: 721))
        #expect(fixture.service.deadline == deadline)
    }

    @Test("Expiry clears the timer and invokes its action once")
    func expiryClearsAndActsOnce() async {
        let fixture = TimerFixture()
        #expect(fixture.service.start(minutes: 1))
        await fixture.sleeper.waitForCallCount(1)

        fixture.clock.advance(seconds: 60)
        await fixture.sleeper.resumeNext()
        await Task.yield()

        #expect(!fixture.service.isActive)
        #expect(fixture.expiryCount == 1)
    }

    @Test("Cancellation prevents expiry and is idempotent")
    func cancellationPreventsExpiry() async {
        let fixture = TimerFixture()
        #expect(fixture.service.start(minutes: 1))
        await fixture.sleeper.waitForCallCount(1)
        fixture.service.cancel()
        fixture.service.cancel()
        await fixture.sleeper.resumeAll()
        await Task.yield()

        #expect(!fixture.service.isActive)
        #expect(fixture.expiryCount == 0)
    }

    @Test("Replacing a timer prevents the old task from expiring the replacement")
    func replacementOwnsExpiry() async {
        let fixture = TimerFixture()
        #expect(fixture.service.start(minutes: 15))
        await fixture.sleeper.waitForCallCount(1)
        #expect(fixture.service.start(minutes: 30))
        await fixture.sleeper.waitForCallCount(2)

        fixture.clock.advance(seconds: 15 * 60)
        await fixture.sleeper.resumeNext()
        await Task.yield()

        #expect(fixture.service.isActive)
        #expect(fixture.expiryCount == 0)

        fixture.clock.advance(seconds: 15 * 60)
        await fixture.sleeper.resumeNext()
        await Task.yield()

        #expect(!fixture.service.isActive)
        #expect(fixture.expiryCount == 1)
    }

    @Test("An early sleep return waits for the remaining deadline")
    func earlySleepReturnWaitsForRemainder() async {
        let fixture = TimerFixture()
        #expect(fixture.service.start(minutes: 1))
        await fixture.sleeper.waitForCallCount(1)
        #expect(await fixture.sleeper.durations() == [.seconds(60)])

        await fixture.sleeper.resumeNext()
        await fixture.sleeper.waitForCallCount(2)
        #expect(await fixture.sleeper.durations() == [.seconds(60), .seconds(60)])

        fixture.clock.advance(seconds: 60)
        await fixture.sleeper.resumeNext()
        await Task.yield()
        #expect(fixture.expiryCount == 1)
    }
}

@MainActor
private final class TimerFixture {
    let clock = TestDateClock()
    let sleeper = ControlledSleeper()
    private let expiryCounter: ExpiryCounter
    let service: SleepTimerService

    var expiryCount: Int {
        self.expiryCounter.count
    }

    init() {
        let expiryCounter = ExpiryCounter()
        self.expiryCounter = expiryCounter
        self.service = SleepTimerService(
            now: { [clock] in clock.now },
            sleep: { [sleeper] duration in try await sleeper.sleep(for: duration) },
            onExpire: { expiryCounter.count += 1 }
        )
    }
}

@MainActor
private final class ExpiryCounter {
    var count = 0
}

private final class TestDateClock: @unchecked Sendable {
    var now = Date(timeIntervalSinceReferenceDate: 0)

    func advance(seconds: TimeInterval) {
        self.now = self.now.addingTimeInterval(seconds)
    }
}

private actor ControlledSleeper {
    private var recordedDurations: [Duration] = []
    private var continuations: [CheckedContinuation<Void, Error>] = []

    func sleep(for duration: Duration) async throws {
        self.recordedDurations.append(duration)
        try await withCheckedThrowingContinuation { continuation in
            self.continuations.append(continuation)
        }
    }

    func durations() -> [Duration] {
        self.recordedDurations
    }

    func waitForCallCount(_ count: Int) async {
        while self.recordedDurations.count < count {
            await Task.yield()
        }
    }

    func resumeNext() {
        guard !self.continuations.isEmpty else { return }
        self.continuations.removeFirst().resume()
    }

    func resumeAll() {
        let pending = self.continuations
        self.continuations.removeAll()
        for continuation in pending {
            continuation.resume()
        }
    }
}
