# GLITCHWORLD: Restore the Lost World

A Roblox (Luau) experience. A digital phenomenon called the Glitch has corrupted the world. You are a young
World Restorer: absorb corrupted energy, restore the environment, free trapped creatures called **Echoes**,
upgrade your gear and rebuild the Green Valley, one object at a time. The valley visibly heals as you progress:
objects swap from glitched to restored, the sky clears and the ground turns green.

Everything is code. The terrain, every prop, the stations, all UI and all systems are generated at runtime from
the scripts in `src/`, so this is a plain [Rojo](https://rojo.space) project with no hand-placed models.

> **Status: untested in Roblox Studio.** This repository was built in an environment without Studio. All logic is
> unit-tested, and the world builders, server, client and UI run end-to-end under a property-validating mock of the
> Roblox API (see [Testing](#testing)). Nobody has looked at it in a real client yet. See
> [What is not verified](#what-is-not-verified) before publishing.

## Quick start

1. Install Rojo 7 (CLI + Studio plugin): <https://rojo.space/docs/v7/getting-started/installation/>
2. `rojo build default.project.json -o GlitchWorld.rbxl`, open it in Studio (or `rojo serve` and press *Connect*).
3. Studio: **Game Settings > Security > Enable Studio Access to API Services** (needed for DataStore saving; without
   it the game runs with in-memory profiles and prints a warning).
4. Press **Play**. Terrain is written first (a couple of seconds), then props, then players spawn.

`default.project.json` turns off `StreamingEnabled` (the valley is small and per-player visuals need every part
present) and `Players.CharacterAutoLoads` (the server spawns a character only after the player's data loaded).

## How to play

| Input | Action |
|---|---|
| **PC**: hold Left Mouse on glowing corruption | absorb (aim with the cursor; hovered targets get an outline) |
| **Mobile**: hold the ABSORB button while facing a target | absorb (auto-targets the nearest target in front) |
| **Gamepad**: hold R2 / R1 | absorb (auto-target) |
| `Q` / L2 / BOOST button | Overcharge gadget (after buying it) |
| `E` / tap / A on a station | open the station / sell fragments / pick up a hidden shard |

The objective card (top centre) always shows the next goal, and a light pillar plus a thin beam points at it.

**Core loop:** absorb corruption -> fragments go to the backpack -> convert them to Credits at the Restoration
Station -> buy upgrades at the Upgrade Station -> restore tougher targets -> free Echoes, find secrets, hit
milestones -> unlock the Frostlight gateway.

## Systems

* **Restoration.** Targets have hp (corruption), a fragment reward, XP, a minimum absorber tier and a visual
  corrupted/restored pair. *Permanent* targets (grass, bushes, trees, crystals, ruins, capsules, obelisks) stay
  restored forever and count towards the area %. *Renewable* nodes (Glitch Bloom, Prism Vein, Surge Node, Rift
  Core) regrow per player and scale income with absorber tier. The valley starts about 65% corrupted
  (measured: 64.7% of scene elements).
* **Equipment.** Absorber (power, speed, range; 5 tiers), Backpack (capacity; 5 tiers), Boots (walk speed, jump;
  5 tiers) and four Gadgets: Verdant Lens, Crystal Lens, Area Siphon, Overcharge Cell. The menu previews
  current -> new stats, price and whether you can afford it.
* **Echoes.** 12 original creatures (Mossbit, Pebblit, Voltling, Prismoo, Frostwhisp, Nullberry, Sparkfin,
  Gearlo, Lumifawn, Cometta, Runeowl, Auroxel), five rarities, each with a *different* kind of passive bonus
  (plant fragments, capacity, absorb speed, crystal fragments, walk speed, sell value, range, ruin fragments, XP,
  regrowth speed, secret sensing, power). They follow you (1 / 2 / 3 slots at ranks 1 / 5 / 12). Unlocked by
  freeing Glitch Capsules, quests, milestones, ranks and finding all hidden shards. No random drops, no gambling,
  nothing to buy.
* **Progression.** Area restoration milestones (10/25/40/60/75/100%), Echo and secret collection milestones,
  rank 1-25 with titles, a 4-branch research tree (Efficiency / Capacity / Exploration / Discovery, 16 nodes,
  Research Points from ranks + milestones), 6 hidden shards, 3 Glitch Obelisks, clue signs.
* **Gateway.** Needs 75% restoration **and** the Advanced Absorber (the ruins are what push you past 73.5%).
  It opens a teaser vista for *Frostlight Peaks*. That region does not exist yet; the sign says so.
* **Tutorial.** A 7-step server-validated quest chain driven by real counters, with a beacon for each step.
* **Persistence.** DataStore with session lock, bounded retries, autosave, save on leave and on shutdown.

## Project layout

| Source | Studio location | Role |
|---|---|---|
| `src/shared/Config.luau` | `ReplicatedStorage.Shared` | **all balance + content**: prices, hp, rewards, xp, bonuses, echoes, research, milestones, quests, sounds |
| `src/shared/WorldData.luau` | | deterministic valley layout, terrain height function, stations, secrets (stable target ids) |
| `src/shared/Rules.luau` | | every game rule as pure functions (stats, buying, rewards, milestones, quests, objective) |
| `src/shared/Profile.luau` | | save schema + defensive reconcile |
| `src/shared/Remotes.luau`, `EchoModel.luau` | | remotes factory; procedural Echo models |
| `src/server/Main.server.luau` | `ServerScriptService.Server` | boot order, player lifecycle |
| `src/server/*Service.luau`, `Sessions`, `Interactions`, `Stations`, `RateLimit` | | authoritative services (data, restoration, economy, equipment, echoes, research, settings, state sync) |
| `src/server/World/*` | | terrain, target models, decor, stations, landmarks, lighting |
| `src/client/*` | `StarterPlayer.StarterPlayerScripts.Client` | HUD, five menus, absorber input, target visuals, feedback, beacon, echo followers, ambience |

### Extending

* **New target type:** add an entry to `Config.Targets`, a builder `B.<type>(ctx)` in
  `server/World/TargetBuilder.luau` (a Corrupted and a Restored look), and placements in `WorldData.luau`.
  Everything else (rewards, UI, tier gating, saving, visuals, beacon) is data-driven.
* **New Echo:** add to `Config.Echoes` (bonus stat keys are summed in `Rules.computeStats`; add a new stat key there
  and to `Economy.CAPS` if it needs a cap). Capsule echoes also need a `capsule` placement with `echo = "<id>"`.
* **New area:** add to `Config.Areas`; unlock requirements are evaluated in `Rules.process`.

Ids are save keys: never rename or reuse one. Add new entries instead.

## Economy

Bonuses from Echoes and research are **added together per stat, capped (`Economy.CAPS`), then applied once** to the
equipment base value, so nothing multiplies through chains. Purchases must go in tier order (no skipping), cost
more each tier and every absorber tier is at least 1.5x faster than the last (enforced by `tests/config_test`).
Fragments that do not fit in the backpack are auto-sold at 50% (75% with the Auto-Sorter research), so a full pack
costs efficiency instead of stopping play.

A greedy "reasonable player" bot plays the real rules on the real map (walking, respawns, backpack trips,
purchases). It is faster than a human, so read these as lower bounds:

| Milestone | Bot time |
|---|---|
| first fragments / first sale | 0:23 / 0:21 |
| first upgrade | 1:05 |
| absorber tier 2 / 3 | 1:50 / 14:21 |
| 25% restored | 4:30 |
| gateway milestone (75%) | 16:55 |
| valley 100% | 21:51 |
| everything bought (all 5 absorber/backpack/boots tiers + 4 gadgets) | 98:16 |

Run `tests/run.sh` to reproduce. Expect real players to take roughly 2-3x as long.

## Security & data model

* The server owns all state. Remotes carry intent only (`start absorbing X`, `buy <category> <id>`); every handler
  validates types, string lengths, ids, ownership/order/funds, proximity to the station and a per-player
  token-bucket rate limit. Rewards are computed on the server from the player's real stats.
* Range, tier and availability are re-checked every server tick while absorbing. A restoration is claimed with a
  check-and-set that has no yield in between, so repeated/simultaneous interactions pay exactly once.
* DataStore: `UpdateAsync` with a per-server session lock (stale after 120 s), exponential backoff capped at 5
  attempts, and **a profile is only ever saved if this server loaded it**. A failed or locked load kicks the player
  with a retry message instead of creating a blank profile that would overwrite their real data. Final saves wait
  for in-flight autosaves. `BindToClose` saves everyone.
* `Profile.reconcile` sanitises whatever comes out of the store (unknown ids dropped, numbers clamped, tiers bounded).

## Testing

Everything below runs without Roblox. You need the [Luau CLI](https://github.com/luau-lang/luau/releases),
[luau-lsp](https://github.com/JohnnyMorganz/luau-lsp/releases) and its
[`globalTypes.d.luau`](https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau):

```sh
LUAU=/path/to/luau LSP=/path/to/luau-lsp DEFS=/path/to/globalTypes.d.luau tests/all.sh
```

1. **Type-check + lint** against the real Roblox API (`tools/check.sh`).
2. **Pure logic** (`tests/run.sh`): config invariants (unique ids, strictly better/pricier tiers, layout spacing,
   slopes, 60-70% starting corruption, tier-gated 75%), rules (stat stacking + caps, buy order/funds/races,
   rewards, duplicate restore, quest chain, milestones, echo unlocks, research, reconcile of garbage data) and the
   economy simulation above.
3. **Mock-Roblox integration** (`tests/smoke.sh`): the *real* `Main.server` and `Main.client` run in one process on
   a mock of the Roblox runtime that rejects unknown property names/methods (built from the official API
   definitions), with a virtual-time scheduler, remotes wired both ways and a DataStore with `UpdateAsync` +
   injectable failures. It checks: the world builds (3.4k instances, terrain slabs validated, every target has both
   states, trees connected, ruin lintels resting on pillars, nothing floating/buried), the full player journey,
   hostile remote input, range/tier gating, a 6-way simultaneous purchase, rate limiting, leave-and-rejoin
   persistence, a session lock held by another server (no overwrite, player kicked), failed loads (bounded retries,
   no blank save), autosave through throttling, `BindToClose`, leaving mid-absorb, per-player independent worlds,
   input -> server -> client visual state, and an analytic UI layout check (overlaps, off-screen elements, text fit)
   for HUD + all five menus at seven viewport sizes from 667x375 to 2560x1440.
4. `tests/preview.sh <dir>` renders PNGs of every target type (both states), the 12 Echoes and a valley map from the
   built world (needs Pillow). Useful for checking geometry without Studio.

## What is not verified

Be explicit about the gaps; these need a real Studio session:

* **Nothing has been seen in a real renderer.** Part geometry was checked numerically and via PNG previews, but
  lighting, materials, particles, the terrain look and overall art have never been viewed. Expect to tune colours.
* **Real DataStore behaviour.** Saving, session locks and retries are tested against a mock. Test in a *published*
  place: join, play, leave, rejoin (see steps below).
* **Real input and device behaviour.** Mouse aim, touch ABSORB button, gamepad, `ProximityPrompt` feel and the
  mobile layout were tested only via synthetic events and arithmetic (no layout engine, no real fonts: the text-fit
  check assumes ~0.54 em per glyph).
* **Audio.** Only built-in `rbxasset://` engine sounds, pitch-shifted. There is **no music**: set
  `Config.Sounds.music.id` to an audio asset you own. Replace the other ids in `Config.Sounds` for real SFX.
* **Performance.** About 2.8k parts and 47 particle emitters in the world, bounded effect counts, bobbing only near
  the camera. Measured nowhere; profile on a low-end phone.
* **Per-player visuals** use client-side `LocalTransparencyModifier`, `CanCollide` and terrain colour overrides.
  This relies on documented client-local behaviour that the mock cannot confirm.

## Not built (by design or scope)

* **Daily quests**, **rebirth/prestige** and **Robux products**: deliberately postponed until the core loop is
  proven fun. Robux must never gate the main game or the collection. When added: cosmetic absorber skins, cosmetic
  Echo appearances, extra *cosmetic* slots, optional convenience; server-validated `ProcessReceipt` with a
  purchase-id ledger in the profile; no fake discounts, no odds-based mechanics.
* **Frostlight Peaks.** The gateway opens onto a labelled teaser only. The planned new mechanic: *Cold Corruption*
  freezes targets solid, and warm Glitch Fragments must thaw them first (a resource-spending mechanic rather than
  only higher prices).
* **Mobility gadget** (dash/glide): boots only change walk speed and jump power.

## Publishing checklist

1. Build with Rojo and play-test in Studio (Output window clean, `[GlitchWorld]` warnings reviewed).
2. Enable API services, publish to a private test place, and test saving: play for a minute, buy something, leave,
   rejoin (progress and echoes must be back); join from two servers with one account (the second must wait/kick
   with the retry message, never reset); shut the server down from the dashboard and check the last save.
3. Test on a real phone and tablet (HUD overlap, ABSORB button vs the jump button, readable text) and a gamepad.
4. Add real audio ids to `Config.Sounds`, a thumbnail, icon, description and age questionnaire. Review the
   monetisation notes above before adding any product.
5. Tune `Config.luau` using real playtest data (the economy bot is only a baseline).
