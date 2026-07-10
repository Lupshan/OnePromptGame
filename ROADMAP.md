# CENDRE — production roadmap

Multi-session production log. **Resume protocol:** read this file, run the
tests (`luajit tests/gen_test.lua`, then the smoke run below if LÖVE is
available), pick the top unchecked item in "Next up", keep this file updated
as you go.

```
# full-game traversal check (headless):
CENDRE_SMOKE=1 CENDRE_SMOKE_FRAMES=32000 xvfb-run love .
# expect: "[smoke] VICTORY" in output, no Error/traceback
```

## Current iteration: 02 — "Recenter on the jumper" ✅ (tagged `iteration-02`)

Versioning convention: one git tag `iteration-NN` per playtested iteration.
`iteration-01` = the state playtested after session 1. NOTE: the session's
git proxy rejects tag pushes (HTTP 403) — tags exist in the local clone and
in this history; push them from a normal checkout if they're missing on
GitHub (`git push origin --tags`).

## Status: COMPLETE PLAYABLE LOOP + FIRST EXPANSION ✅ (session 1)

Title → charselect → run (4 biomes × ~7 rooms + boss each) → death/victory →
cinders → Kiln unlocks → new run. Verified end-to-end by autopilot traversal
(latest check: 29 rooms, 4 bosses, VICTORY, zero errors, zero fallback rooms).

## Done

### Session 1 (2026-07-09)
- [x] Core: seeded RNG streams, event bus, state machine, save/profile, input (kb+pad)
- [x] Physics: tile AABB, one-way platforms, corner correction, ledge step-up, raycast
- [x] Player feel: coyote, jump buffer, apex float, jump cut, wall slide/jump,
      8-way dash + i-frames, 3-hit combo with soft auto-aim, pogo, homing bolt
- [x] Juice: hitstop, screenshake, squash/stretch, flashes, slowmo, pooled particles (6 kinds)
- [x] Audio: sfxr-style synth (25 sfx recipes ×4 variants), generative music
      (coprime-length layers, per-biome moods, boss intensity), safe when no audio device
- [x] Levelgen: ASCII chunk library (30 chunks), assembly, **reachability proof**
      (conservative jump model), safe fallback; 0.04% fallback rate over 2520 rooms
- [x] Enemy engine: 8 parametric behaviors, 15 enemies across 3 biomes, elites,
      status effects (burn/chill/shock/doom/weaken), depth scaling
- [x] Boss engine: coroutine patterns, phases, intro banners, add-cap, cleanup on kill
- [x] 3 bosses: Pyravore (ashfall), Drowned Choir (duskmire), Last Warden (spire/final)
- [x] Run structure: StS-style graph (guaranteed shop/rest/treasure/elite), map UI
- [x] Rooms: combat waves w/ telegraphed spawns, platform/treasure/rest/shop/event/boss,
      props (chest, altar, fountain, shrine, shop pedestals), locked doors, rewards
- [x] Boons: 6 families + neutral, 41 boons (10 duos, 6 legendaries), rarities,
      idempotent rebuild pipeline, stat caps vs degenerate combos
- [x] Characters: 4 sidegrade wraiths (3 unlockable)
- [x] Meta: cinders, the Kiln (7 unlocks: characters + pool wideners), codex, stats
- [x] States/UI: title, charselect, rungame (map/boonpick/pause), gameover, victory, kiln, codex, HUD
- [x] Tests: headless gen test (luajit-only), full-game smoke autopilot (reaches VICTORY)
- [x] README with extension guide; this roadmap

### Session 1, expansion pass (same day)
- [x] Biome 4: The Ember Sea (order 3; Hollow Spire is now the 4th, final biome)
- [x] Boss 4: Tide of Coals (dive/erupt, coal rain, floor skimmers)
- [x] +6 enemies (ash_hound, splitter, mortar_shell, leech_wisp, warden_shield, ember_skirmisher)
      with new engine mechanics: split-on-death, heal-on-hit
- [x] Elite modifiers: volatile / regenerating / vampiric / stormtouched
- [x] +15 chunks (new entries/exits, arenas, first biome-restricted set) — 0 fallbacks/1890 rooms
- [x] +12 boons: all 15 family pairs now have duo payoffs; new legendary (Glasswing);
      burn-duration support (Slow Roast) wired into the status engine
- [x] Depth scaling capped for 4-biome length (hp <=4.2x, damage <=2.4x)
- [x] Shrine outcome table deepens behind the Listening Stones unlock
- [x] Pause menu with live settings (music/sfx volume, screen shake, abandon)

### Iteration 02 (2026-07-10) — post-playtest correction brief
- [x] i18n: locale system, full en/fr UI + full fr content catalogue,
      language switch in Options + pause (persisted)
- [x] Key remapping (capture UI, persisted, reset) + How to Play screen +
      first-room key hints with live bindings
- [x] ONE attack identity: bolt removed, lunge removed, melee chains with
      movement; bolt boons/characters reworked (Heat Haze, Storm Brand,
      Withering Mark, Skyfang, Glasswing; Stormcaller = air kit)
- [x] LEVELGEN RECENTERED: rooms are traversal challenges — walk-only flood
      proves the exit is NEVER reachable on flat ground (acceptance test,
      asserted in tests/gen_test.lua: 0 leaks); diagonal-jump reachability
      model; variable door heights; vertical climb/descent rooms; traversal
      chunk set rebuilt with real verticality; arena = only sealed fight
      (1/biome + boss); enemies as placed hazards; optional-combat sigils;
      perched challenge sigils
- [x] Mobility as progression: air-dash charges, glide, spring jumps
      (Twin Gale / Ashwing / Spring Step), hard caps; levelgen stays
      calibrated on the base kit (documented in generator.lua)
- [x] Map readability: bright selectable paths, traveled trail, "you are
      here", explicit localized labels, UTF-8 uppercase for accents

## Next up (session 3+ / iteration 03 candidates, in rough priority order)

- [ ] **Playtest feedback pass** on iteration 02 (expect movement-feel tuning
      in config.lua and chunk difficulty rebalancing)
- [ ] **More vertical chunks** (wall-jump chimneys once the validator models
      wall jumps; currently single-jump ladders only)
- [ ] **Traversal variety**: moving platforms, crumble blocks, dash crystals
      (mid-air dash refill pickups — pure traversal tools, Celeste-style)

Widen and deepen — keep every addition coherent with the existing loop.

- [ ] **Heat/ascension system**: post-victory difficulty modifiers (unlock-gated, opt-in;
      difficulty up, never player power up — respects the no-power-creep rule)
- [ ] **Room objectives variety**: survive-the-timer, protect-the-ember, no-ground challenge rooms
- [ ] **Weapon variety per character** (alternate melee arcs as unlockable kits)
- [ ] **More enemies** (guardian that shields allies, burrower, mirror-image caster...)
- [ ] **More boons**: pogo/traversal-build depth, boon-count synergies
- [ ] **Minibosses** mid-biome (elite++ with one boss pattern each)
- [ ] **Codex depth**: per-entry detail pane, kill counts, boon synergy hints
- [ ] **Daily seed mode** (fixed seed of the day + simple local leaderboard)
- [ ] **Performance pass**: particle caps under load, room draw batching (fine so far)
- [ ] **Steam wrap**: luasteam bindings, achievements list, cloud save of profile.lua

## Known rough edges (fix opportunistically)

- Music layers render on first biome entry (~0.5s hitch per new mood); could pre-render async
- Smoke autopilot uses cheats by design; a real "AI player" test would exercise combat honestly
- Enemy `armoredFront` logic is convoluted (works, but rewrite when touched)
- `exit_perch` chunk's decorative platform is unreachable (cosmetic only)
- Shop restock: shops always offer 1 heal + boons; could vary (dash charge, max-hp shard...)

## Human-only (explicitly out of scope for generation)

- **Feel tuning by play**: all constants live in `src/core/config.lua`; the starting
  values follow the Celeste/SMB reference numbers but only hands on a controller
  can sign off. Everything else is automatable here.
