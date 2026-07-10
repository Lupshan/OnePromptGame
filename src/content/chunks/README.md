# Chunk authoring

A chunk is a slice of room, 20 tiles tall, any width (12-24 is typical).
Rooms are built by concatenating chunks horizontally between two door walls,
then validated for reachability (see `src/game/levelgen/reachability.lua`).
If a generated room fails validation it is regenerated with other chunks, so
an imperfect chunk degrades gracefully — but every chunk should stay
provably traversable under the FULL-KIT envelope below.

## Iteration-03 design rules (see docs/level-design-notes.md)

Each chunk is ONE intentional platforming problem with a name and an idea —
never filler geometry. `platforming.lua` holds the single-jump problems,
`kitwork.lua` the full-kit families (gap / gate / updraft / chimney /
rhythm / drop / squeeze). Enemies are placed ON the intended line, safety
nets cost damage rather than the run, and difficulty tiers 1-3 escalate
across a room (the generator ramps tiers across its middle slots).

## Full-kit movement envelope (what the validator can prove)

- climbs up to **5 rows** (4-5 = double jump territory);
- jumps up to **9 columns**, minus 1 per row risen (6+ = dash territory;
  distances are column counts: a 4-tile air gap = 5 columns);
- **wall-jump chimneys**: two facing solid walls 2-4 clear columns apart
  climb any height while both walls persist; a break of ≤ 2 rows in ONE
  wall is crossable while the other is solid; the top of a wall is a
  landing right where it ends. Wall tops need feet+head clearance, so
  keep them at row ≥ 3 (vclimb) / clear of the room ceiling.
- Boon mobility (extra air-dashes, glide) is NEVER required — it only buys
  fluidity and optional skips.

## Legend

| char | meaning |
|------|---------|
| `#`  | solid tile |
| `.`  | empty |
| `-`  | one-way platform |
| `^`  | spikes (hazard) |
| `e`  | ground enemy spawn |
| `f`  | flying enemy spawn |
| `c`  | treasure spot (chest) |
| `h`  | heal fountain |
| `s`  | shop pedestal |
| `n`  | boon altar |
| `*`  | ember light (decor glow) |

## Fields

- `id`: unique string.
- `kind`: `combat` | `platform` | `entry` | `exit` | `treasure` | `rest` | `shop` | `event`
- `entry`, `exit`: `low` | `mid` | `high` — approximate elevation of the open
  path at the chunk's left/right edge. Used to chain chunks plausibly.
- `difficulty`: 1-3, gates hard chunks to deeper rooms.
- `biomes`: optional list of biome ids this chunk is restricted to.
- `unlock`: optional meta-unlock id required before this chunk enters the pool.
- `map`: the ASCII grid (20 rows). Short rows are right-padded with `.`.

Add a file in this folder returning a list of chunk defs and they are picked
up automatically by the game — but also add it to the file lists in
`tests/gen_test.lua` (headless tests can't enumerate the directory the same
way and must name files explicitly).

One more chaining rule learned the hard way: a chunk whose `entry` is
HIGHER than its own `exit` (e.g. `high` → `low`) can be asked to follow
itself when the pool is thin — the generator falls back to the raw pool
when no chunk fits a seam. Such chunks must also be enterable at their exit
height (a jumpable route from a low seam into the problem, like
`drop_shafts`' bottom corridor or `drop_wells`' floor pockets), or every
retry chain-fails.

## Iteration-02 discipline (walkability)

Traversal chunks (`kind = "platform"`) must be IMPOSSIBLE to cross by walking
and falling alone: put a real gap, a climb, or a hazard belt on every path.
The generator rejects any room whose exit is walk-reachable (see
`reachability.lua: walkFlood`), so a walkable chunk is dead weight.

Entry/exit tags now carry real heights: `low` = ground top row 18,
`mid` = ledge top row 12, `high` = ledge top row 6 — the ledge must touch the
chunk's edge on the tagged side. A seam may DROP any amount (falling is
free) but only rises when tags match exactly.

Vertical chunks (`kind = "vclimb" | "vdescent"`, 24 columns wide) stack into
shafts. Climb contract: a rung on row 20 (author columns 12-15) and one on
row 2 (columns 7-10), joined by an internal ladder; prefer one-way platform
rungs (`-`) — the player can rise through them, so seams always connect.
