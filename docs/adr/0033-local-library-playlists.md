# ADR-0033: Local Guest Library Playlists

## Status

Accepted

## Context

The YouTube Music Library endpoint is account-scoped, so the existing Library
route and playlist creation flow required a signed-in Google account. Guest
users could browse and play public content, but they had no way to retain a
personal playlist inside Kaset.

## Decision

Kaset supports a local Library playlist subset for guest users.

- Local playlists are stored as Codable JSON in the app's Application Support
  directory.
- Local playlist IDs use the `local:` prefix and are never sent to YouTube
  Music API endpoints.
- The Library route remains available to guests and shows local playlists.
- Signed-in users continue to receive their YouTube Music Library, with local
  playlists merged into the same view.
- Account-backed features such as liked music, history, YouTube Library
  mutations, and private playlist synchronization remain sign-in-only.

## Consequences

Local playlists are available offline on the same Mac but do not synchronize
with YouTube, other devices, or Google accounts. A local playlist can be
created from the current queue and can receive additional songs through the
local playlist context menu.
