# Combat notes — research before implementation (iteration 03)

What makes fast-action combat feel sharp, lethal and mobile, distilled from
published material on the reference games. Sources at the bottom.

## Why the current attack fails (playtest diagnostic)

Slow (0.26s between swings), reads as a vague "wave" (an arc outline drawn
in front of the body), carries no impact event, ignores the player's
momentum, and matches nothing in the art direction. Enemies are HP sponges,
so the optimal play is stand-and-spam. Every one of those is a known,
documented failure mode.

## From Vlambeer ("The Art of Screenshake", JW Nijman)

The talk's core: ~30 small tweaks turn a dull action loop into a great one.
The ones that matter for a melee slash:
1. **Fast, snappy animation** — attack starts on frame 1 of the press.
   Anticipation frames are for enemies (telegraphs), not for the player.
2. **Hitstop** — freeze the world 1-3 frames on connect; bigger on kill.
   The pause IS the weight.
3. **Screenshake scaled to the event** — small per hit, big per kill/finisher.
4. **Knockback both ways** — the victim flies, the attacker recoils a hair
   (or is pulled forward); bodies must MOVE when struck.
5. **Impact effects at the contact point** — sparks/flash where the blade
   meets the enemy, not on the attacker.
6. **Enemy hit reaction** — white flash + interrupted animation, instantly.
7. **Lower enemy HP, more enemies** — deaths are the fun event; make them
   frequent. Big HP pools defer the payoff and read as mush.
8. **Permanence** — corpses/shards linger so a fight leaves a mark.
9. **Sound layering** — sharp transient on swing, meatier crunch on hit,
   distinct kill sound.

## From Hollow Knight (nail design)

10. **Instant directional slash**: hits in front / up / down from input
    direction, active for a few frames, chains freely. The arc drawing is a
    crescent SLASH shape (a blade smear), not a wireframe arc.
11. **Every hit gives double feedback**: enemy flashes white AND both
    parties get knocked back. Small enemy knockback makes spacing dynamic.
12. **Pogo (down-strike bounce)** is a combat AND traversal verb — keep it
    central, it is the bridge between our two pillars.

## From Dead Cells / Hades (lethality & mobility)

13. **Low time-to-kill both ways**: trash dies in 1-2 hits; elite/boss are
    the only long fights. The player is also fragile — a hit matters. This
    kills stand-and-spam: repositioning between swings is the skill.
14. **Mobility is a combat resource**: dash i-frames, dash-through, jump
    resets — the fight is choreography, not DPS. Movement options must be
    frequent and strong, not rare trinkets.
15. **Un-cancellable frames are a deliberate cost**: our choice — the slash
    is fully cancellable by dash/jump (Bayonetta school) because CENDRE's
    identity is momentum; the cost lever is the attack cooldown instead.

## Our implementation targets

- C1. Attack cooldown ~0.16s (was 0.26); combo window generous; finisher
      every 3rd hit with heavier hitstop/shake.
- C2. Slash renders as a filled crescent smear along the swing direction in
      the character's glow color, alive for ~4 frames, plus a contact flash
      AT THE ENEMY and round spark particles (player = round language).
- C3. Hitstop: ~0.03s hit / ~0.09s kill / ~0.12s finisher-kill. Shake
      likewise scaled. Attacker micro-recoil; victim knockback up.
- C4. Enemy HP cut ~40% across the board and depth HP scaling flattened;
      trash at depth 0 dies in 1-2 hits. Enemy count per fight can rise.
- C5. Player fragility: lower max HP (100 -> 70), rarer healing; the
      attempts pool (death model, level notes R8) makes hits consequential.
- C6. Mobility up: base dash cooldown down; mobility boons more frequent
      in offers and stronger per pick.
- C7. Shape language (readability): PLAYER IS ROUND (friendly, agile);
      ENEMIES ARE ANGULAR (threat) — triangles point along their movement
      or attack direction; enemy projectiles are shards, player effects are
      round. Applied across body, particles, telegraphs, projectiles.

## Sources

- [Jan Willem Nijman (Vlambeer) — "The Art of Screenshake" (INDIGO 2013)](https://www.youtube.com/watch?v=AJdEqssNZ-U)
- [Vlambeer co-founder shares advice on building better action games — Game Developer](https://www.gamedeveloper.com/design/vlambeer-co-founder-shares-advice-on-building-better-action-games)
- [The Art of Screenshake — annotated notes](https://theengineeringofconsciousexperience.com/jan-willem-nijman-vlambeer-the-art-of-screenshake/)
- [Hollow Knight nail mechanics — wiki](https://hollowknight.wiki/w/Nail)
- [Hollow Knight Design Critique — gamedev.net](https://gamedev.net/tutorials/game-design/game-design-and-theory/hollow-knight-design-critique-r4996)
- [Dead Cells mechanics — wiki](https://deadcells.wiki.gg/wiki/Mechanics)
- [Un-cancellable attack frames — Dead Cells community discussion](https://steamcommunity.com/app/588650/discussions/0/1700542332315457762/)
- [Shape language in character design](https://pixune.com/blog/shape-language-technique/)
