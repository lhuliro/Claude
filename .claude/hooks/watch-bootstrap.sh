#!/usr/bin/env bash
# SessionStart: prepare the watch skill in cloud sessions (fresh containers lose
# ffmpeg/yt-dlp/WhisperX setup). Runs detached so the session is not delayed.
[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0
ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
bash "$ROOT/.claude/skills/watch/scripts/cloud-bootstrap.sh" --bg
exit 0
