<h1 align="center">Kaset</h1>

<p align="center">A native macOS client for YouTube Music and YouTube, built with Swift and SwiftUI.</p>

<p align="center">
  <a href="https://trendshift.io/repositories/16570?utm_source=repository-badge&amp;utm_medium=badge&amp;utm_campaign=badge-repository-16570"><img src="https://trendshift.io/api/badge/repositories/16570" alt="sozercan/kaset | Trendshift" width="200" height="44"/></a>
</p>

> **Personal fork:** This repository tracks
> [`sozercan/kaset`](https://github.com/sozercan/kaset) while maintaining the
> additional features listed below. See
> [Maintaining the Personal Fork](docs/maintaining-personal-fork.md) for the
> branch model and upstream synchronization workflow. When upstream changes
> conflict with these features, their intended behavior is preserved and the
> upstream implementation is adapted around them.

<table>
  <tr>
    <th>YouTube Music</th>
    <th>YouTube</th>
  </tr>
  <tr>
    <td><img src="docs/screenshot-ytm.png" alt="Kaset YouTube Music screenshot"></td>
    <td><img src="docs/screenshot-yt.png" alt="Kaset YouTube screenshot"></td>
  </tr>
</table>

## Features

### Added in This Fork

The following features are maintained on top of the upstream Kaset repository:

- 📚 **Local Guest Library and Playlists** — Use Library without signing in,
  create and manage multiple playlists stored locally on this Mac, and add songs
  from song menus throughout the app. Local playlists do not require or modify
  a Google account.
- 🛡️ **Experimental Track-Boundary Ad Handling** — Ad-blocking extensions may
  not work reliably with YouTube Music playback inside WebKit. Two independent,
  default-off options under Settings → General → Experimental provide narrow
  fallbacks: **Skip end-of-track ads** advances through Kaset's normal queue
  logic when an ad starts at the measured end of a song, while **Retry song on
  pre-roll ads** reloads the same requested song once when an ad appears before
  the music begins. These options do not block ad requests, do not handle
  mid-roll ads, and cannot guarantee that YouTube will not return another ad.
  See [Track-Boundary Advertisement Experiments](docs/track-boundary-ad-experiments.md)
  for technical details.
- ❎ **Close Button for the Sign-In Sheet** — Adds a Close button so the
  sign-in sheet can be dismissed without authenticating. Google sign-in remains
  available and continues to work normally whenever account features are
  needed.
- 🔒 **Local-Build Update Isolation** — Automatic Sparkle updates are disabled
  so a personally built app is not silently replaced by an upstream release.

### Music & Video

- 🎵 **Native macOS Experience** — Apple Music-style UI with Liquid Glass player bars, clean sidebar navigation, and a source toggle for Music ↔ YouTube
- 🎧 **YouTube Music Support** — Full playback of DRM-protected YouTube Music content via your existing Premium subscription
- ▶️ **[YouTube Support](docs/youtube.md)** — Browse regular YouTube recommendations, search, subscriptions, Shorts, Watch Later, history, comments, and video playback with native controls, captions, quality selection, and picture in picture

### Playback

- 🎚️ **Equalizer** — System-wide 6-band parametric EQ with Spotify-style presets, applied to WebKit playback output
- 📜 **Lyrics** — View plain and synced lyrics with line-by-line highlighting when timing data is available, plus AI-powered explanations and mood analysis on macOS 26+
- 📃 **Queue Management** — View, reorder, shuffle, and clear your playback queue
- 🔀 **Smart Shuffle** — Beyond plain shuffle: blends suggested tracks into the queue based on what you're playing, with cadence and how many are queued ahead configurable in Settings
- 🔊 **Background Audio** — Music continues playing when the window is closed; stops on quit
- 🎶 **Track Notifications** — Get notified when a new track starts playing

### Library & Discovery

- 📚 **Library Access** — Browse playlists, liked songs, and subscribed podcasts; create playlists, add songs to playlists, and delete your own playlists
- 🧭 **Explore** — Discover new releases, charts, and moods & genres
- 🎙️ **Podcasts** — Browse and listen to podcasts with episode progress tracking
- 🔍 **Search** — Find songs, albums, artists, playlists, and podcasts
- 🕓 **History** — Revisit recently played tracks

### macOS Integration

- 🎛️ **System Integration** — Now Playing in Control Center, media key support, Dock menu controls
- ✨ **Apple Intelligence** — On-device AI for natural language commands, lyrics explanations, and playlist refinement on macOS 26+
- ⌨️ **[Keyboard Shortcuts](docs/keyboard-shortcuts.md)** — Full keyboard control for playback, navigation, and more
- 📳 **Haptic Feedback** — Tactile feedback on Force Touch trackpads for player controls and navigation
- 📣 **Share** — Share songs, playlists, albums, and artists via the native macOS share sheet
- 🌍 **Localized** — UI available in 17 languages (Arabic, Chinese (Simplified), Chinese (Traditional), Dutch, English, French, German, Indonesian, Italian, Korean, Polish, Portuguese, Russian, Spanish, Swedish, Turkish, Ukrainian); change under Settings → General → Language

### Automation & Extensibility

- 🧩 **[Extensions](docs/extensions.md)** — Load WebKit Web Extensions, including [uBlock Origin Lite](https://github.com/uBlockOrigin/uBOL-home) and [SponsorBlock](https://github.com/ajayyy/SponsorBlock)
- 🔗 **[URL Scheme](docs/url-scheme.md)** — Open songs directly with `kaset://play?v=VIDEO_ID`; app-targeted YouTube watch and `youtu.be` links play in YouTube mode
- 🤖 **[AppleScript Support](docs/applescript.md)** — Automate playback with scripts, Raycast, Alfred, and Shortcuts

## Requirements

- macOS 15.4 or later
- Apple Intelligence features require macOS 26.0 or later
- A [Google](https://accounts.google.com) account is required for account-based
  YouTube Music and YouTube features
- Guest users can use the local Library and local playlists without signing in

## Installation

### Kaset Extended Releases

Download the latest Kaset Extended build from the
[Kaset Extended Releases](https://github.com/huylaez/kaset-extended/releases)
page. Releases are unsigned personal builds.

Because the application bundle is currently still named `Kaset.app`, installing
it replaces the installed application at `/Applications/Kaset.app`.
Quit Kaset first, then copy the downloaded app into Applications:

```bash
ditto Kaset.app /Applications/Kaset.app
open /Applications/Kaset.app
```

If macOS blocks the unsigned app after downloading it, you can approve it from
the macOS user interface:

1. Try opening the app once.
2. Open **System Settings → Privacy & Security**.
3. Scroll to the **Security** section.
4. Click **Open Anyway** for Kaset Extended.
5. Confirm by clicking **Open**.

Alternatively, Control-click `Kaset.app`, choose **Open**, and confirm the
prompt. Only bypass this warning if you obtained the app from a trusted source.

Advanced users can clear the quarantine attribute from Terminal:

```bash
xattr -cr /Applications/Kaset.app
```

### Build Locally

Build an unsigned local application from the current branch:

```bash
KASET_SIGNING=unsigned Scripts/build-app.sh release
```

The resulting application is `.build/app/Kaset.app`. To replace the installed
application with this local build:

```bash
ditto .build/app/Kaset.app /Applications/Kaset.app
open /Applications/Kaset.app
```

To create a DMG for local distribution, use `create-dmg` with the resulting
application bundle. The DMG filename and volume label may identify it as a
Kaset Extended build, while the application inside remains `Kaset.app`.

## Contributing

For branch ownership, personal feature precedence, and branch maintenance, see
[Maintaining the Personal Fork](docs/maintaining-personal-fork.md).

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, architecture,
and coding guidelines.

## Disclaimer

Kaset is an unofficial application and not affiliated with YouTube or Google Inc. in any way. "YouTube", "YouTube Music" and the "YouTube Logo" are registered trademarks of Google Inc.
