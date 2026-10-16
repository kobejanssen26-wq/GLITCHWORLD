# NEONFORGE audio pack (original, synthesised by tools/audio/make_audio.py)
7 music loops (music_hub, music_zone_a..f) and 13 sound effects (sfx_*.ogg). Roblox cannot import audio from a repo,
so upload them once: Creator Hub > Assets > Audio > Bulk upload (free for short clips, check current limits).
Then paste each asset id into `src/shared/AudioIds.luau` (`rbxassetid://<id>`), rebuild, and publish.
Until you do, the game uses built-in engine sounds as fallback (no music).
Regenerate: `python3 tools/audio/make_audio.py audio` (needs numpy + ffmpeg).
