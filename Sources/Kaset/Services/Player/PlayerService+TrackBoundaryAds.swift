import Foundation

// MARK: - Track Boundary Advertisements

@MainActor
extension PlayerService {
    func beginTrackBoundaryAdPlaybackSelection(videoID: String, queueEntryID: UUID?) {
        let owner = TrackBoundaryAdPlaybackOwner(queueEntryID: queueEntryID, videoID: videoID)
        self.preRollAdRetryState = PreRollAdRetryState(owner: owner)
    }

    func preserveTrackBoundaryAdPlaybackSelection(videoID: String, queueEntryID: UUID?) {
        let owner = TrackBoundaryAdPlaybackOwner(queueEntryID: queueEntryID, videoID: videoID)
        if self.preRollAdRetryState.owner != owner {
            self.preRollAdRetryState = PreRollAdRetryState(owner: owner)
        }
    }

    func restartTrackBoundaryAdPlaybackSelectionForCurrentTrack() {
        guard let owner = self.currentTrackBoundaryAdPlaybackOwner else { return }
        self.beginTrackBoundaryAdPlaybackSelection(
            videoID: owner.videoID,
            queueEntryID: owner.queueEntryID
        )
    }

    func recordAuthoritativeContentProgressForBoundaryAds(
        _ progress: TimeInterval,
        observedVideoID: String?
    ) {
        guard let owner = self.currentTrackBoundaryAdPlaybackOwner,
              observedVideoID == owner.videoID
        else { return }
        self.preserveTrackBoundaryAdPlaybackSelection(
            videoID: owner.videoID,
            queueEntryID: owner.queueEntryID
        )
        guard TrackBoundaryAdPolicy.hasAuthoritativeContentProgressed(progress) else { return }
        self.preRollAdRetryState.hasAuthoritativeContentProgressed = true
        self.preRollAdRetryState.retryAttempt = 0
    }

    func prepareTrackBoundaryAdTransition(
        isAdRisingEdge: Bool,
        isCurrentDocument: Bool,
        contentOccurrence: MusicPlaybackOccurrence?,
        intent: MusicPlaybackIntent
    ) -> TrackBoundaryAdTransition? {
        let settings = self.trackBoundaryAdSettingsProvider()
        let hasCurrentIntent = self.acceptsMusicPlaybackIntent(intent)
        let expectedVideoID = self.currentTrackBoundaryAdPlaybackOwner?.videoID
        let contentDuration = expectedVideoID.flatMap(self.observedDuration(for:)) ?? 0
        let contentIdentityMatches = expectedVideoID != nil
            && self.lastNonAdContentVideoId == expectedVideoID
        let contentOccurrenceMatches = expectedVideoID != nil
            && contentOccurrence?.videoId == expectedVideoID

        let endInput = EndOfTrackAdDecisionInput(
            isEnabled: settings.skipsEndOfTrackAds,
            isAdRisingEdge: isAdRisingEdge,
            songNearingEnd: self.songNearingEnd,
            contentProgress: self.lastNonAdContentProgress,
            contentDuration: contentDuration,
            contentIdentityMatchesRequestedTrack: contentIdentityMatches,
            hasCurrentPlaybackIntent: hasCurrentIntent,
            hasCurrentPlaybackOccurrence: contentOccurrenceMatches,
            isExplicitPauseIntentActive: self.isExplicitPauseIntentActive
        )
        if TrackBoundaryAdPolicy.shouldCompleteTrack(for: endInput),
           let expectedVideoID,
           let contentOccurrence
        {
            return .completeTrack(
                observedVideoID: expectedVideoID,
                occurrence: contentOccurrence,
                intent: intent
            )
        }

        guard let owner = self.currentTrackBoundaryAdPlaybackOwner else { return nil }
        self.preserveTrackBoundaryAdPlaybackSelection(
            videoID: owner.videoID,
            queueEntryID: owner.queueEntryID
        )
        let preRollInput = PreRollAdDecisionInput(
            isEnabled: settings.retriesPreRollAds,
            isAdRisingEdge: isAdRisingEdge,
            hasRequestedTrack: true,
            hasCurrentPlaybackIntent: hasCurrentIntent,
            isCurrentDocument: isCurrentDocument,
            hasAuthoritativeContentProgressed: self.preRollAdRetryState
                .hasAuthoritativeContentProgressed,
            retryAttempt: self.preRollAdRetryState.retryAttempt,
            isExplicitPauseIntentActive: self.isExplicitPauseIntentActive
        )
        guard TrackBoundaryAdPolicy.shouldRetryTrack(for: preRollInput) else { return nil }
        self.preRollAdRetryState.retryAttempt += 1
        return .retryTrack(intent: intent)
    }

    func performTrackBoundaryAdTransition(_ transition: TrackBoundaryAdTransition) async {
        switch transition {
        case let .completeTrack(observedVideoID, occurrence, intent):
            self.logger.info("Completing track after measured end-boundary advertisement transition")
            await self.handleTrackEnded(
                observedVideoId: observedVideoID,
                playbackOccurrence: occurrence,
                intent: intent
            )
        case let .retryTrack(intent):
            // Stop the detected advertisement before the full-page reload is scheduled.
            SingletonPlayerWebView.shared.pause()
            await self.retryCurrentTrackAfterPreRollAd(intent: intent)
        }
    }

    private var currentTrackBoundaryAdPlaybackOwner: TrackBoundaryAdPlaybackOwner? {
        guard let videoID = self.normalizedPlaybackVideoId(
            self.pendingPlayVideoId ?? self.currentTrack?.videoId
        ) else { return nil }
        return TrackBoundaryAdPlaybackOwner(
            queueEntryID: self.activePlaybackQueueEntryID,
            videoID: videoID
        )
    }

    private func retryCurrentTrackAfterPreRollAd(intent: MusicPlaybackIntent) async {
        guard self.acceptsMusicPlaybackIntent(intent),
              !self.isExplicitPauseIntentActive,
              let owner = self.currentTrackBoundaryAdPlaybackOwner,
              self.preRollAdRetryState.owner == owner
        else { return }

        let playback: (song: Song, queueEntryID: UUID?)? = if let queueEntryID = owner.queueEntryID,
                                                              let entry = self.queueEntries.first(where: {
                                                                  $0.id == queueEntryID
                                                              }),
                                                              entry.song.videoId == owner.videoID
        {
            (entry.song, queueEntryID)
        } else if let currentTrack = self.currentTrack,
                  currentTrack.videoId == owner.videoID
        {
            (currentTrack, nil)
        } else {
            nil
        }
        guard let playback else { return }

        self.logger.info("Retrying current track once after measured pre-roll advertisement transition")
        await self.play(
            song: playback.song,
            webLoadStrategy: .forceFullPageWhenSameVideoId,
            queueEntryID: playback.queueEntryID,
            preservesPreRollAdRetryState: true,
            intent: intent
        )
    }
}
