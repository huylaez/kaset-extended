import Foundation

// MARK: - Track Boundary Advertisement Policy

/// Immutable user preferences consumed by the playback boundary policy.
struct TrackBoundaryAdSettings: Equatable, Sendable {
    let skipsEndOfTrackAds: Bool
    let retriesPreRollAds: Bool
}

/// Inputs for deciding whether an advertisement transition should complete the current track.
struct EndOfTrackAdDecisionInput: Equatable, Sendable {
    let isEnabled: Bool
    let isAdRisingEdge: Bool
    let songNearingEnd: Bool
    let contentProgress: TimeInterval
    let contentDuration: TimeInterval
    let contentIdentityMatchesRequestedTrack: Bool
    let hasCurrentPlaybackIntent: Bool
    let hasCurrentPlaybackOccurrence: Bool
    let isExplicitPauseIntentActive: Bool
}

/// Inputs for deciding whether an advertisement transition should retry the requested track.
struct PreRollAdDecisionInput: Equatable, Sendable {
    let isEnabled: Bool
    let isAdRisingEdge: Bool
    let hasRequestedTrack: Bool
    let hasCurrentPlaybackIntent: Bool
    let isCurrentDocument: Bool
    let hasAuthoritativeContentProgressed: Bool
    let retryBudgetConsumed: Bool
    let isExplicitPauseIntentActive: Bool
}

enum TrackBoundaryAdPolicy {
    /// The measured end advertisement began with 0.021 seconds of authoritative content remaining.
    /// Reuse the existing manual terminal-seek tolerance while still requiring `songNearingEnd`.
    static let terminalRemainingThreshold: TimeInterval = 0.5

    /// The measured pre-roll advertisement began before any positive authoritative content sample.
    /// Any positive accepted sample permanently disqualifies later ads for that playback selection.
    static let contentStartThreshold: TimeInterval = 0

    static func shouldCompleteTrack(for input: EndOfTrackAdDecisionInput) -> Bool {
        guard input.isEnabled,
              input.isAdRisingEdge,
              input.songNearingEnd,
              input.contentIdentityMatchesRequestedTrack,
              input.hasCurrentPlaybackIntent,
              input.hasCurrentPlaybackOccurrence,
              !input.isExplicitPauseIntentActive,
              input.contentProgress.isFinite,
              input.contentProgress >= 0,
              input.contentDuration.isFinite,
              input.contentDuration > 0,
              input.contentProgress <= input.contentDuration
        else { return false }

        return input.contentDuration - input.contentProgress <= Self.terminalRemainingThreshold
    }

    static func shouldRetryTrack(for input: PreRollAdDecisionInput) -> Bool {
        input.isEnabled
            && input.isAdRisingEdge
            && input.hasRequestedTrack
            && input.hasCurrentPlaybackIntent
            && input.isCurrentDocument
            && !input.hasAuthoritativeContentProgressed
            && !input.retryBudgetConsumed
            && !input.isExplicitPauseIntentActive
    }

    static func hasAuthoritativeContentProgressed(_ progress: TimeInterval) -> Bool {
        progress.isFinite && progress > Self.contentStartThreshold
    }
}

struct TrackBoundaryAdPlaybackOwner: Equatable {
    let queueEntryID: UUID?
    let videoID: String
}

struct PreRollAdRetryState: Equatable {
    var owner: TrackBoundaryAdPlaybackOwner?
    var hasAuthoritativeContentProgressed = false
    var retryBudgetConsumed = false
}

enum TrackBoundaryAdTransition: Equatable {
    case completeTrack(
        observedVideoID: String,
        occurrence: MusicPlaybackOccurrence,
        intent: MusicPlaybackIntent
    )
    case retryTrack(intent: MusicPlaybackIntent)
}
