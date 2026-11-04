---
title: "Locate house_control.env by __file__ path, not cwd"
author: YuTzu2003
date: 2026-11-04
branch: feature/auto-machine
cost: { minutes: 83, tokens: 214173 }
id: l-61644b98
scope: repo
status: active
src: agent
touches:
  - pi/house_control/youtube_player.py
  - pi/house_control/controller.py
  - lib/mqtt_youtube_service.dart
  - pi/start.sh
  - lib/main.dart
---

## Decided
Use `Path(__file__).resolve().parent.parent` to locate `house_control.env` instead of `Path.cwd()`.

## Tried and ruled out
- `Path.cwd() / "house_control.env"`: CWD is not guaranteed to be the `pi/` directory at runtime, even though `start.sh` does `cd "$PROJECT_DIR"`. The Python process may inherit a different CWD.
- `set -a; source house_control.env; set +a` in `start.sh`: exports vars to the shell, but the Python subprocess did not reliably receive them.
- `os.environ.setdefault()`: does not override existing empty or default values; switched to direct `os.environ[key] = value`.
- Module-level `AUDIO_DEVICE = os.environ.get(...)`: evaluated at import time before `_load_env_file()` runs; replaced with a lazy `_audio_device()` function.

## Watch out
The controller module is at `pi/house_control/controller.py`. Two `.parent` hops from `__file__` land on `pi/`, where `house_control.env` lives. If the directory structure changes, this path breaks.

In the code:
- `pi/house_control/controller.py`: `_load_env_file()` uses `Path(__file__).resolve().parent.parent / "house_control.env"`
- `pi/house_control/youtube_player.py`: `_audio_device()` reads `os.environ` lazily at call time, not at import time
