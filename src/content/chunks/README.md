# Chunk authoring

A chunk is a slice of room, 20 tiles tall, any width (12-24 is typical).
Rooms are built by concatenating chunks horizontally between two door walls,
then validated for reachability (see `src/game/levelgen/reachability.lua`).
If a generated room fails validation it is regenerated with other chunks, so
an imperfect chunk degrades gracefully — but try to keep every chunk
traversable left-to-right with single jumps (max gap 4 tiles, max climb 3).

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
up automatically — no other wiring needed.

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
