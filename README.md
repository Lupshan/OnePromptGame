# CENDRE

*The world burned. Keep moving.*

A nervous roguelike jumper: Celeste-school platforming precision crossed with
a Hades-school run structure. **Everything is procedural** — every sprite is
drawn by code, every sound synthesized at runtime, every level generated and
*proven traversable* before you set foot in it. There is not a single image,
audio or font file in this repository.

- **Move like a knife.** Coyote time, jump buffering, apex float, corner
  correction, wall jumps, an 8-way dash with i-frames — tuned so the game
  never feels like it betrayed you.
- **Build like a gambler.** Boons from six Remnants (Ember, Tempest, Gloom,
  Verdance, Aegis, Zephyr) stack into builds; duo boons unlock when you cross
  two families and blow the run wide open.
- **Die like it matters.** Death sends you back with nothing but *cinders* —
  meta-currency that unlocks new characters, boons and rooms at the Kiln.
  Unlocks widen what can happen; they never make you stronger. Every run
  starts at base power.

## Running the game

1. Install [LÖVE 11.5](https://love2d.org/) (`apt install love`, `brew install love`, or the Windows installer).
2. From the repository root:

```
love .
```

That's it. No build step, no assets to fetch.

Useful flags & environment:

| invocation | effect |
|---|---|
| `love . --seed 12345` | jump straight into a run with a fixed seed (same seed → same run) |
| `CENDRE_SMOKE=1 love .` | autopilot smoke mode (drives itself through a full run; used for CI/testing) |

### Controls

| action | keyboard | gamepad |
|---|---|---|
| move | arrows / WASD | left stick / d-pad |
| jump (hold = higher) | Space / C / K | A |
| attack (3-hit combo, up/down aims) | X / J | X |
| bolt (auto-aim ranged) | V / L | Y |
| dash (8-way, i-frames) | Shift / I | B / RB |
| interact | E | d-pad up |
| map / skip boon | Tab | Back |
| pause | Esc / P | Start |

Down+attack in the air pogo-bounces off enemies. Down+jump drops through platforms.

## Testing without a display

```
luajit tests/gen_test.lua          # level generation + reachability across ~2500 rooms
CENDRE_SMOKE=1 CENDRE_SMOKE_FRAMES=32000 xvfb-run love .   # full-game autopilot to victory
```

The smoke autopilot cheats on purpose (culls enemies, teleports to exits): its
job is to traverse every system — rooms, waves, bosses, boons, map, biome
transitions, victory — and crash loudly if any of them break.

## Extending the content

The whole game is registry-driven: **content is files, not code changes**.
Drop a Lua file in the right folder under `src/content/` and it is picked up
automatically at startup (`src/game/registry.lua` scans the folders).

### Add an enemy

Create (or append to a list in) `src/content/enemies/my_pack.lua`:

```lua
return {
  {
    id = "ash_hound",
    name = "Ash Hound",
    desc = "It remembers being loyal.",       -- codex flavor
    behavior = "charger",     -- walker|flyer|turret|floater|orbiter|charger|caster
    shape = "husk",           -- blob|spikeball|wisp|totem|shell|husk|shade|dervish
    w = 16, h = 14,
    hp = 40, damage = 12, speed = 60,
    aggroRange = 180,
    color = { 0.6, 0.45, 0.4 },
    weight = 3,               -- spawn weight
    minDepth = 2,             -- optional: only deeper rooms
    unlock = nil,             -- optional: meta-unlock gate
  },
}
```

Then reference its id in a biome's `enemyWeights` (or don't — it stays in the
global fallback pool). Behaviors are parametric state machines in
`src/game/enemy.lua`; add a new behavior function there if the existing eight
don't fit.

### Add a boon

Append to any file in `src/content/boons/` (or make a new file):

```lua
{
  id = "smoldering_wake",
  family = "ember",                -- ember|tempest|gloom|verdance|aegis|zephyr|ash
  name = "Smoldering Wake",
  flavor = "Where you walked, it remembers.",
  maxLevel = 3,
  desc = function(level, rarityMult)
    return ("Landing ignites enemies within %d px."):format(30 + 10 * level * rarityMult)
  end,
  apply = function(run, ctx)       -- re-run on every boon change; keep idempotent
    ctx.on("playerLand", function(player)
      for _, e in ipairs(run.currentRoom:enemiesInRadius(player:center())) do ... end
    end)
    run:addMult("moveSpeedMult", 0.05 * ctx.level * ctx.mult)
  end,
}
```

`apply` receives the run plus `ctx = { level, mult, on, group }`. Register
hooks with `ctx.on(event, fn)` (auto-cleaned when boons rebuild) and stats
with `run:addFlat` / `run:addMult`. Useful events: `playerAttack`, `playerDash`,
`playerJump`, `playerLand`, `playerHurt`, `playerPreHurt` (mutable `ev`),
`enemyDamaged`, `enemyKilled`, `boltHit`, `statusApplied`, `shieldBroken`,
`roomEntered`, `roomObjectiveDone`, `tick` (dt, room, run).
Duo boons set `family2` + `duo = true`. Stat caps in `src/game/run.lua`
keep combos from going degenerate — respect them.

### Add a room chunk

Drop an ASCII map into `src/content/chunks/` — the format, legend, and
traversal rules (max 4-tile gaps, max 3-tile climbs, the 18/15/12/9 ledge
ladder) are documented in `src/content/chunks/README.md`. Broken chunks can't
soft-lock the game: every generated room is validated by a conservative
reachability model (`src/game/levelgen/reachability.lua`) and regenerated or
replaced by a safe fallback if it fails — but a chunk that always fails is
dead weight, so run `luajit tests/gen_test.lua` after authoring.

### Add a biome

Copy any file in `src/content/biomes/`: palette, ambient particle style,
generative-music mood, enemy weights, boss id. Set `order` to place it in the
run. Add a matching boss in `src/content/bosses/` (coroutine attack patterns
over a helper API — `radial`, `aimed`, `charge`, `leapTo`, `shockwave`,
`summon`; see `pyravore.lua` for the simplest example).

### Add a character / meta unlock

Characters: `src/content/characters/` — sidegrade kits only (the no-power-creep
rule applies to characters too). Unlocks: `src/content/unlocks/` — they may
only *widen the content pool*, never grant starting power.

## Architecture map

```
main.lua / conf.lua        entry, LÖVE config
src/core/                  config (all tuning), rng streams, save, signals, input, state machine
src/render/                procedural drawing, camera, particles, juice, biome backgrounds
src/audio/                 synth (sfxr-style), sfx recipes, generative layered music
src/game/                  physics, player, enemy engine, boss engine, room, run, graph,
                           boons system, projectiles, pickups, levelgen (+ reachability proof)
src/content/               THE GAME: biomes, enemies, bosses, boons, chunks, characters, unlocks
src/states/                title, charselect, rungame, gameover, victory, kiln, codex
src/ui/                    hud, boon cards, run map
tests/                     headless generation tests (plain luajit, no LÖVE needed)
```

Design rules the code holds itself to (see `ROADMAP.md` for status):

1. **Zero external assets.** Nothing references a `.png`, `.wav`, or font file.
2. **No power creep.** Meta-progression unlocks content, never stats.
3. **No softlocks.** Every room proves reachability or is replaced by a safe layout.
4. **No degenerate combos.** Stat caps + per-proc guards on every boon interaction.
5. **Seeded runs.** Same seed, same run — always reproducible for debugging.

## Steam

The game is plain LÖVE and wraps for Steam without code changes (bundle as a
`.love` with the official runtime, add [luasteam](https://github.com/uspgamedev/luasteam)
bindings later for achievements/cloud saves). Nothing in the code assumes a
particular distribution.
