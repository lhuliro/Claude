# Cloud / phone adaptation of the watch skill

Vendored from https://github.com/bradautomates/claude-video (skills/watch, v0.3.2,
commit 03ceb42, MIT — see LICENSE) and adapted to run in Claude Code cloud sessions
started from the Claude mobile app.

## Changes from upstream

| File | Change | Why |
|---|---|---|
| `scripts/cloud-bootstrap.sh` (new) | Installs ffmpeg, latest yt-dlp[curl-cffi] + deno, writes default config, installs WhisperX. Idempotent, `--bg` mode. | Cloud containers start fresh every session. |
| `../../hooks/watch-bootstrap.sh` + `../../settings.json` (new) | SessionStart hook runs the bootstrap in the background, only when `CLAUDE_CODE_REMOTE=true`. | Tools are ready by the time you paste a link. |
| `scripts/setup.py` | Installs `torchvision==0.23.0` from the PyTorch CPU index together with torch/torchaudio. | Upstream bug on Linux: PyPI's CUDA torchvision mismatches CPU torch (`torchvision::nms does not exist`). |
| `scripts/config.py`, `scripts/local_whisperx.py` | New `WATCH_WHISPERX_VAD=silero|pyannote` setting (default silero, cloud bootstrap sets pyannote). | Silero is fetched from github.com by torch.hub, which the cloud proxy blocks; pyannote VAD weights ship inside WhisperX. |
| `SKILL.md` | "Cloud / phone sessions" section: wait for bootstrap, skip the wizard, platform notes. | No interactive setup needed on the phone. |

Upstream's 249 tests pass against these scripts.

## Tested (2026-11-26)
- Instagram public reel → 24 frames + WhisperX transcript in ~20 s.
- TikTok metadata OK. YouTube metadata OK, media download 403 from cloud IPs (use captions or Gemini).

## Optional: Gemini engine
With a Gemini key the whole video (picture + sound) is analysed by Google's model, and
YouTube works. In a cloud session, add the key as a network secret for host
`generativelanguage.googleapis.com` (header `x-goog-api-key`), then put
`GEMINI_API_KEY=proxy-injected` in `~/.config/watch/.env` (or set env var
`WATCH_GEMINI_VIA_PROXY=1` on the environment so the bootstrap writes it).
