#!/usr/bin/env bash
# Cloud-session bootstrap for the watch skill (Claude Code on the web / phone).
#
# Cloud containers start fresh, so tools, config and the WhisperX environment are
# lost between sessions. This script restores all of it. It is idempotent: a warm
# container finishes in well under a second.
#
#   bash cloud-bootstrap.sh          # run in the foreground
#   bash cloud-bootstrap.sh --bg     # detach; progress goes to ~/.cache/watch/bootstrap.log
#
# Status files: ~/.cache/watch/bootstrap.done (success) / bootstrap.failed (with reason).
set -u

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STATE_DIR="$HOME/.cache/watch"
LOG="$STATE_DIR/bootstrap.log"
DONE="$STATE_DIR/bootstrap.done"
FAILED="$STATE_DIR/bootstrap.failed"
LOCK="$STATE_DIR/bootstrap.lock"
CONFIG="$HOME/.config/watch/.env"
mkdir -p "$STATE_DIR" "$HOME/.config/watch"

if [ "${1:-}" = "--bg" ]; then
  nohup bash "$0" >"$LOG" 2>&1 </dev/null &
  exit 0
fi

exec 9>"$LOCK"
if command -v flock >/dev/null 2>&1; then flock 9; fi

rm -f "$DONE" "$FAILED"
fail() { echo "[bootstrap] FAILED: $*"; echo "$*" >"$FAILED"; exit 1; }
log() { echo "[bootstrap] $(date +%H:%M:%S) $*"; }

PY=python3
command -v "$PY" >/dev/null 2>&1 || fail "python3 is missing"

# 1. ffmpeg / ffprobe
if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then
  log "installing ffmpeg"
  if command -v apt-get >/dev/null 2>&1; then
    SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
    $SUDO apt-get update -qq && DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y -qq ffmpeg || fail "apt-get install ffmpeg failed"
  else
    fail "ffmpeg missing and apt-get unavailable"
  fi
fi

# 2. yt-dlp (latest, sites break old releases) + curl-cffi impersonation + deno JS runtime
PIP_FLAGS="-q --disable-pip-version-check"
"$PY" -m pip install $PIP_FLAGS --help 2>/dev/null | grep -q -- --break-system-packages && PIP_FLAGS="$PIP_FLAGS --break-system-packages"
if [ ! -f "$STATE_DIR/ytdlp.$(date +%Y%m%d)" ]; then
  log "installing/upgrading yt-dlp"
  "$PY" -m pip install $PIP_FLAGS -U "yt-dlp[default,curl-cffi]" deno || fail "pip install yt-dlp failed"
  touch "$STATE_DIR/ytdlp.$(date +%Y%m%d)"
fi
command -v yt-dlp >/dev/null 2>&1 || fail "yt-dlp not on PATH after install"

# 3. Watch config defaults (never overwrite a value the user already set)
set_default() {
  grep -q "^$1=" "$CONFIG" 2>/dev/null || printf '%s="%s"\n' "$1" "$2" >>"$CONFIG"
}
touch "$CONFIG"; chmod 600 "$CONFIG"
set_default WATCH_ENGINE auto          # Gemini when GEMINI_API_KEY resolves, else local frames+transcript
set_default WATCH_DETAIL balanced
set_default WATCH_WHISPER_BACKEND whisperx
set_default WATCH_WHISPERX_VAD pyannote # silero needs github.com via torch.hub, often blocked in sandboxes
# Gemini key through the cloud proxy: if a network secret for generativelanguage.googleapis.com
# is configured, the proxy injects the real key, so a placeholder is enough locally.
if [ -n "${WATCH_GEMINI_VIA_PROXY:-}" ]; then set_default GEMINI_API_KEY proxy-injected; fi

# 4. WhisperX (local speech-to-text for reels without captions). ~30 s on a fresh container.
if [ ! -f "$STATE_DIR/whisperx-venv/.deps-ok" ] || ! grep -q '^SETUP_COMPLETE=' "$CONFIG"; then
  log "installing WhisperX"
  "$PY" "$SKILL_DIR/scripts/setup.py" --backend whisperx --detail balanced || fail "WhisperX install failed (see $LOG)"
fi

"$PY" "$SKILL_DIR/scripts/setup.py" --check || fail "setup.py --check failed"
date >"$DONE"
log "watch skill ready"
