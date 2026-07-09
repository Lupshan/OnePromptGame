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

## Status: COMPLETE PLAYABLE LOOP ✅ (session 1)

Title → charselect → run (3 biomes × ~7 rooms + boss each) → death/victory →
cinders → Kiln unlocks → new run. Verified end-to-end by autopilot traversal.

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

## Next up (session 2+, in rough priority order)

Widen and deepen — the loop is done, so everything below is additive content
or polish. Keep every addition coherent with the existing loop.

- [ ] **Content: more enemies** (aim +6–10: ranged skirmisher, shielder that guards allies,
      splitter that spawns mites on death, mortar, leech that heals off the player...)
- [ ] **Content: more chunks** (aim +15–20: vertical shafts using mid/high doors,
      one-way descent chunks, hazard-dense unlockable set, biome-restricted chunks)
- [ ] **Content: more boons** (aim +15: remaining duo pairs (ember×zephyr, tempest×verdance,
      tempest×aegis, gloom×verdance, aegis×zephyr), more legendaries, bolt-build depth)
- [ ] **Content: biome 4 "The Ember Sea"** + boss (extends run length option; consider
      making biomesPerRun selectable 3/4 as an unlock — content, not power)
- [ ] **Elite modifiers** (volatile: explodes; frostbound: chills on hit; vampiric...)
      instead of plain stat-up elites
- [ ] **Miniboss/event depth**: shrine event table expansion behind `shrine_events` unlock
      (currently unlock exists; wire richer outcomes when it's owned)
- [ ] **Weapon variety per character** (alt melee arcs / bolt patterns as unlockable kits)
- [ ] **Room objectives variety**: survive-the-timer, protect-the-ember, no-ground challenge rooms
- [ ] **Pause menu settings**: volume sliders, screenshake toggle wiring (save.settings exists)
- [ ] **Heat/ascension system**: post-victory difficulty modifiers (unlock-gated, opt-in;
      difficulty up, never player power up — respects the no-power-creep rule)
- [ ] **Codex depth**: per-entry detail pane, kill counts, boon synergy hints
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
