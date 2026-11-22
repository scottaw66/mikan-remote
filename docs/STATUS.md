---
app: mikanremote
name: MikanRemote
status: private
platforms: [mac, ios]
channel: [dmg-self-update, devicectl]
owner: internal
site: ""
next: ""
updated: 2026-11-22
---

# MikanRemote: status

Mikan Remote turns an iPhone into a trackpad and button remote for a Mac playing video, over the local network. Latest tag: `mikanremote-v1.4.0` (2026-11-22); the Mac server is 1.4.0 (build 4) and the iPhone client 1.4.0 (build 6). Between 1.3.0 and 1.4.0 the iPhone had two layout-only versions the same day (1.3.1, 1.3.2) with no Mac release: an iPhone-only change doesn't ship one. It's Scott's own tool and private: not something he'll release (Scott, 2026-11-05).

## Where things are

- Two apps sharing the MikanProtocol package: MikanRemoteServer, a Mac menu bar app, and the MikanRemote iPhone client with a share extension.
- Mac server: notarized DMG and its own updater since 1.2.0 (2026-10-16). Releases go to an unlisted feed on mikansoftware.app and Scott installs from the app.
- iPhone client: a Release build installed straight to Scott's iPhone with devicectl (`MikanRemote/scripts/deploy.sh`). It stays out of TestFlight (Scott, 2026-11-02).
- Latest features: a top-bar button that brings the Mac's browser to the front, fullscreen video first (2026-11-22, 1.4.0); browser back/forward buttons, a Watch Later button and a Save / Unsave button that works through the Watch Later Solo Safari extension (2026-11-22, 1.3.0); remote keyboard and a YouTube Home button (2026-09-13); page scroll buttons (2026-08-23).
- Scott uses it on the exercise bike, so settings must be hard to trigger by accident.

## Next

- Nothing recorded yet.

More history: git tags, and `~/Brain/Areas/Apps/Memory/` (mikanremote's notes).
