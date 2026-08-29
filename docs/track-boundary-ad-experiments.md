# Track-Boundary Advertisement Experiments

## Status

Implemented behind two independent, default-off experimental settings. Unit
verification is complete. Packaged runtime re-verification is still required
because YouTube Music's advertisement behavior is controlled remotely and can
change without a Kaset release.

## Purpose

Kaset can observe advertisements that replace music playback at either edge of
a requested YouTube Music track:

- an end-of-track advertisement can take over just before WebKit reports the
  music media as ended;
- a pre-roll advertisement can take over before the requested music produces
  its first accepted progress sample.

The two experiments respond narrowly to those transitions:

| Setting | Detected boundary | Native action |
| --- | --- | --- |
| **Skip end-of-track ads** | An ad starts within the measured terminal boundary | Complete the old track through Kaset's normal terminal path |
| **Retry song on pre-roll ads** | An ad starts before the requested content has begun | Reload the same requested track up to three times without changing the queue index |

These features are not general ad blocking. They do not intercept network
requests, alter YouTube responses, hide DOM elements, or handle mid-roll ads.

## Runtime Investigation

### Method

The behavior was investigated in a packaged app because playback happens in a
hidden DRM-capable `WKWebView`, and source inspection alone cannot establish
the ordering of WebKit bridge events.

Temporary timestamped instrumentation was added to the real playback-state
path in `MiniPlayerWebView+Coordinator.swift`. It wrote a sanitized trace to
`NSTemporaryDirectory()` inside the app sandbox. The trace contained only
structural playback state such as:

- ad-state transitions;
- numeric progress and duration;
- whether the sample was authoritative music content;
- document, media, and native playback generations;
- playback-intent and occurrence relationships;
- `songNearingEnd` and terminal-event state.

It did not record cookies, tokens, authorization headers, account identifiers,
response bodies, or personal playlist content. The temporary instrumentation
and copied trace were removed after the measurements were captured.

### Observed Pre-Roll Sequence

The observed pre-roll advertisement changed `isAd` from `false` to `true` at
exactly `0.0` seconds. No positive authoritative content sample for the
requested song had been accepted first.

This observation supports a strict start policy:

```text
contentStartThreshold = 0 seconds
content has started    = accepted authoritative progress > 0
```

Once positive music progress has been accepted for a playback selection, a
later advertisement cannot be classified as pre-roll. This also prevents a
manual seek back to `0:00` from creating a new retry opportunity.

### Observed End-of-Track Sequence

The observed end advertisement changed `isAd` from `false` to `true` at:

```text
last content progress = 183.77218761299665 seconds
content duration      = 183.7935 seconds
remaining time        = approximately 0.021 seconds
songNearingEnd        = true
accepted TRACK_ENDED  = none before the ad transition
```

The trace also showed that YouTube changed advertisement media multiple times
before eventually moving to another song. The ad media therefore cannot become
the identity used to complete the old content track.

The implementation uses a conservative `0.5`-second terminal threshold. This
reuses Kaset's existing terminal-seek tolerance while also requiring the
independent `songNearingEnd` latch. Both conditions must pass.

### Why the UI Clock Is Not Evidence

The visible `0:00` and `-0:00` labels are formatted presentation values. They
discard fractional seconds and can remain unchanged while WebKit switches
between music and ad media. The decision policy uses finite numeric progress,
duration, media identity, and lifecycle state instead.

## Playback State Model

The implementation separates four concepts that can temporarily disagree:

- **Playback intent** identifies the music request Kaset currently owns. A
  stale bridge callback cannot act after a newer user or queue action replaces
  that intent.
- **Playback occurrence** identifies one concrete WebView music occurrence by
  its document, media, and native generations. Terminal claims use occurrences
  to suppress duplicate completion.
- **Authoritative content state** is progress and duration from ready non-ad
  music media. Ad samples may update transport state, but they do not replace
  the canonical music clock.
- **Advertisement state** is tracked separately. Only a newly accepted
  `false -> true` edge can trigger either experiment.

The high-level path is:

```text
WebView STATE_UPDATE
        |
        v
validate document generation, playback intent, and occurrence
        |
        v
classify sample as authoritative content or advertisement
        |
        +---- content ----> update canonical music clock
        |                   latch positive progress for pre-roll policy
        |
        +---- ad edge ----> evaluate end-of-track policy
                            otherwise evaluate pre-roll policy
                                      |
                         +------------+------------+
                         |                         |
                         v                         v
                  handleTrackEnded(...)     retry same intent up to three times
```

The end policy is evaluated before the pre-roll policy because an ad replacing
a nearly completed song must consume the old terminal occurrence, not be
interpreted as an ad before a new song.

## Skip End-of-Track Ads

### Acceptance Policy

`TrackBoundaryAdPolicy.shouldCompleteTrack(for:)` accepts the transition only
when every guard is true:

1. The setting is enabled.
2. The sample is a new `false -> true` ad-state edge.
3. `songNearingEnd` is true.
4. The last non-ad content identity matches the requested track.
5. A current music playback intent still owns the request.
6. The preserved content occurrence belongs to the requested track.
7. No explicit pause intent is active.
8. Content progress is finite, non-negative, and not beyond duration.
9. Content duration is finite and positive.
10. No more than `0.5` seconds remain.

If any guard fails, normal YouTube playback remains in control.

### Terminal Occurrence Preservation

At the ad rising edge, the incoming WebView sample may already describe ad
media. The coordinator captures the currently accepted music occurrence before
processing that sample. When the boundary transition is accepted, it deliberately
does not bind the incoming ad occurrence first.

This ordering matters:

```text
correct:   preserve content occurrence -> decide -> complete content
incorrect: bind ad occurrence          -> decide -> lose old terminal owner
```

The preserved content occurrence is passed to `handleTrackEnded(...)`.
`claimTerminalMusicPlaybackOccurrence(...)` then provides the same duplicate
suppression used by a natural `TRACK_ENDED` event. If a delayed WebKit terminal
event arrives later, it cannot advance the queue a second time.

### Queue Semantics

The experiment never calls `next()` directly. Routing through
`handleTrackEnded(...)` preserves existing behavior for:

- repeat off, repeat one, and repeat all;
- the final queue item;
- explicit pause intent;
- stale event rejection;
- autoplay suppression;
- duplicate terminal occurrences.

The feature synthesizes evidence that the old track reached its terminal
boundary; it does not introduce a separate queue policy.

## Retry Song on Pre-Roll Ads

### Acceptance Policy

`TrackBoundaryAdPolicy.shouldRetryTrack(for:)` accepts the transition only when
every guard is true:

1. The setting is enabled.
2. The sample is a new `false -> true` ad-state edge.
3. A requested track and current playback intent exist.
4. The event belongs to the current WebView document generation.
5. No positive authoritative music progress has been accepted for the current
   playback selection.
6. Fewer than three retry attempts have been made for the selection.
7. No explicit pause intent is active.

### Retry Ownership and Budget

`PreRollAdRetryState` is owned by a pair of identifiers:

```text
(queue entry ID, requested video ID)
```

This distinguishes duplicate video IDs in a queue while still supporting
playback outside a queue. An accepted pre-roll transition increments the retry
attempt count before starting the asynchronous reload. At most three attempts
are allowed.

The reload uses the existing native `play(...)` path with
`forceFullPageWhenSameVideoId`. It preserves the original playback intent and
queue entry and does not advance the queue.

The replacement WebView media occurrence created by that reload does not reset
the retry count. Therefore this sequence terminates safely:

```text
requested song -> pre-roll ad -> automatic same-song retry -> another ad
                                                         -> retry up to two more times
                                                         -> no further retry
```

A new explicit song selection, an explicit restart, or advancement to another
queue item creates a new playback owner and restores all retry attempts. Accepted
positive music progress latches the selection as having started, so later ads
remain ineligible even if playback seeks back to zero.

### Why the Setting Is Named "Retry"

Kaset cannot guarantee that reloading the requested track will remove the ad.
YouTube may return the same ad, another ad, or the requested song. The label
describes the action Kaset controls without promising an outcome controlled by
YouTube.

## Settings and Persistence

Both options are available under **Settings -> General -> Experimental** and
default to `false`:

| Setting | `UserDefaults` key |
| --- | --- |
| Skip end-of-track ads | `settings.experimental.skipEndOfTrackAds` |
| Retry song on pre-roll ads | `settings.experimental.retrySongOnPreRollAds` |

`SettingsManager` reads the values locally from the app's `UserDefaults`
domain. No account, Keychain, server, or cloud synchronization is involved.
The current values are injected into the runtime decision point, while the pure
policy receives immutable Boolean inputs for deterministic testing.

Changing a toggle affects only future ad rising edges. Enabling an option while
an ad is already active does not retroactively trigger an action, and disabling
an option after an action was accepted does not undo that action.

## Safety Properties

The implementation is intentionally fail-closed. Missing, stale, mismatched, or
non-finite state results in no synthetic transition.

Important protections include:

- document-generation validation rejects callbacks from replaced pages;
- playback-intent validation rejects callbacks superseded by newer actions;
- video identity validation prevents one song's clock from completing another;
- occurrence identity and terminal claims prevent duplicate advancement;
- ad samples never overwrite authoritative music progress or duration;
- explicit pause intent blocks both automatic actions;
- a rising-edge requirement prevents repeated polling samples from retriggering;
- a three-attempt limit prevents pre-roll reload loops.

No new dependency, entitlement, server request, cookie access, telemetry event,
or authentication behavior is introduced by these experiments.

## Tests

The focused tests cover:

- every individual acceptance guard;
- invalid progress and duration values;
- the measured terminal boundary and an out-of-boundary ad;
- preservation and identity validation of the terminal occurrence;
- three-attempt retry limit preservation across replacement media occurrences;
- rejection after accepted positive content progress;
- manual seek-to-zero behavior;
- explicit selection reset behavior;
- independence of the two settings;
- default and persisted `UserDefaults` values;
- localization catalog parity.

The primary focused command is:

```bash
swift test --skip KasetUITests --filter TrackBoundaryAd
```

Runtime verification should use a packaged build and cover Search/Home
playback, local playlists, authenticated playback, repeat modes, pause near the
end, rapid manual Next, and consecutive pre-roll advertisements. Temporary
diagnostic traces must be removed before committing.

## Limitations

- The behavior depends on YouTube Music's current WebView state and may require
  adjustment if its player or ad signaling changes.
- The end threshold is based on one sanitized measured transition. The
  `songNearingEnd` and identity guards reduce risk, but broader packaged runtime
  verification is still required.
- Retrying a pre-roll ad does not guarantee ad-free playback.
- Mid-roll ads are deliberately ignored.
- The first version applies to YouTube Music playback, not ordinary YouTube
  video playback.
- Neither option prevents advertisement resources from being downloaded.

## Implementation Landmarks

- `Sources/Kaset/Services/Player/TrackBoundaryAdPolicy.swift`
- `Sources/Kaset/Services/Player/PlayerService+TrackBoundaryAds.swift`
- `Sources/Kaset/Services/Player/PlayerService+PlaybackControls.swift`
- `Sources/Kaset/Services/Player/PlayerService+WebQueueSync.swift`
- `Sources/Kaset/Views/MiniPlayerWebView+Coordinator.swift`
- `Sources/Kaset/Services/SettingsManager.swift`
- `Sources/Kaset/Views/GeneralSettingsView.swift`
- `Tests/KasetTests/TrackBoundaryAdPolicyTests.swift`
- `Tests/KasetTests/PlayerServiceTrackBoundaryAdTests.swift`

The implementation plan and runtime checklist are maintained in
`docs/end-of-track-ad-auto-advance-plan.md`.
