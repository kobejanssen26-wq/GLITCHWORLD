# NEONFORGE
Roblox tycoon + obby hybrid. Run a neon ore factory on your own plot (droppers, upgraders, generators, collector),
then climb a 12-floor spiral tower (85 obstacle modules: lasers, pistons, turntables, vanishing tiles, bounce pads,
speed gaps...) for crowns, cash, trails and auras. Prestige with **Overdrive**. Each floor has its own sky, particles and music.

## Quick start
1. Open `dist/Neonforge.rbxl` (binary, 0.35 MB) or `dist/Neonforge.rbxlx` (XML, 16 MB, same game) in Roblox Studio.
2. Optional audio: see `audio/README.md` (10 MB pack in `dist/Neonforge-audio.zip`).
3. Press Play. Publish to Roblox to enable DataStore saving (Game Settings > Security > API services).
Or build yourself: `rojo build default.project.json -o dist/Neonforge.rbxl`.

## Layout
`src/shared` rules/config, `src/server` services, `src/client` UI/FX, `tools/bake` world generator (-> `world/World.rbxm`),
`tools/audio` sound synth, `tests/` (`tests/all.sh`).

## Honest notes
- Not yet played in real Studio; verified by pure tests, a mock-Roblox harness, luau-lsp type-check and a software renderer.
- DataStore, physics of movers/spinners and Material enum values in the baked map are untested live.
- File size: the game itself is code + parts, which compress to ~0.35 MB. The 16 MB .rbxlx is the same content as XML; real MB of
  content comes from the audio pack.
- The earlier GLITCHWORLD concept was removed, but it still exists in git history.
