---
title: Unified player replaces separate music and YouTube modes
author: YuTzu2003
date: 2026-11-04
branch: feature/auto-machine
cost: { minutes: 15, tokens: 80860 }
id: l-bfdb885d
scope: repo
status: active
src: agent
touches:
  - ARCHITECTURE.md
  - lib/main.dart
  - lib/mqtt_light_service.dart
  - lib/mqtt_music_service.dart
  - lib/mqtt_rfid_service.dart
  - lib/mqtt_scene_service.dart
  - lib/mqtt_settings.dart
  - lib/mqtt_youtube_service.dart
  - lib/youtube_page.dart
  - pi/README.md
---

## Decided
Merged the music mode and YouTube mode into a single unified player. The YouTube player service handles all audio playback because it has more features (volume control via mpv IPC, title display, pause/resume). The old music service MQTT topics (`house/music/*`) are still handled by `music.py` on the Pi for backward compatibility with scenes that reference device "music", but the Flutter app no longer creates `MqttMusicService` connections.

Added pause/resume via mpv JSON IPC `cycle pause` command, with `get_property pause` to read back the actual state.

Added Android share intent support so YouTube links shared from the YouTube app open the player and auto-play.

## Watch out
- Scenes that use `device: "music"` still work through the old `music.py` on the Pi side. Do not remove `music.py` without migrating scenes.
- The `receive_sharing_intent` package requires the `ACTION_SEND` intent filter in AndroidManifest.xml. iOS would need a similar share extension setup.
- mpv `cycle pause` is asynchronous; the code sleeps 150ms before reading the pause property back. If the read races, the status might report the wrong state briefly.

In the code:
- Pi pause: `_mpv_command(ipc_path, ["cycle", "pause"])` then `_mpv_get_property(ipc_path, "pause")`
- MQTT topic: `house/youtube/pause`
- Share intent listener: `_MainShellState` in main.dart, using `ReceiveSharingIntent.instance`
- `YouTubePage` accepts `initialUrl` param for auto-play on share
