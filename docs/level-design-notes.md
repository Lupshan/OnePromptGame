# Level design notes — research before authoring (iteration 03)

Principles gathered from published material on the reference games, distilled
into rules our chunks and generator must follow. Sources at the bottom.

## From Celeste (Maddy Thorson, GDC "Designing Celeste")

1. **A room is a small, self-contained story** with a fixed dramaturgy:
   - **Beginning** — the player can scope out the room and its key details
     from where they stand. No blind leaps.
   - **Tension** — an initial problem that uses the room's idea.
   - **Climax** — a final, harder problem: the same idea at full strength.
   - **Resolution** — a safe ledge, a reward, a breath.
2. **One idea per room.** A room introduces or twists ONE mechanic.
   Escalation happens across rooms, not by piling mechanics into one screen.
3. **Multiple solutions, one obvious goal.** Like a climbing wall: the exit
   is visible, the path is the player's choice (dash over vs. hop across).
   Authoring implication: leave slack — two viable lines through most chunks.
4. **Safety decreases along the room.** Early beats have safe ground to
   stand on and think; the climax may demand commitment (no rest mid-air).
   Never open a room with its hardest jump.
5. **Teach silently**: the first use of an idea is in a place where failure
   is cheap (a spike pit next to safe ground), then the same idea over a
   real drop.

## From Super Meat Boy (Edmund McMillen, "Why So Hard")

6. **Short and dense beats long and sparse.** Small rooms where the goal is
   visible lower stress and re-traversal cost. Density of interesting
   decisions per meter is the quality metric — empty flat runs are dead air.
7. **The designer is a teacher; escalation is the lesson plan.** Same
   obstacle, tighter execution, over the biome: intro (generous margins) →
   standard → expert (tight margins + hazards stacked).
8. **Failure must be cheap and fast.** Instant restart keeps momentum; the
   punishment is repeating the ROOM, not the run. (Feeds the iteration-03
   death model: death = room restart, costs one attempt from a small pool.)

## From Dead Cells (Sébastien Bénard, "a hybrid approach")

9. **The algorithm assembles; humans author.** Every tile/chunk is a
   hand-designed room built FOR A PURPOSE (combat room ≠ treasure room ≠
   transit room). The generator's job is restrained: pick and connect
   authored templates along a hand-designed macro graph. It never invents
   geometry.
10. **Templates carry intent metadata** (purpose, difficulty, connections)
    so the assembler can place them meaningfully, not randomly.

## Our rules (what the code/content must enforce)

- R1. Chunk = one intentional platforming problem, named after its idea
      (`gap`, `rhythm`, `dashgate`, `chimney`, `pogo`, `drop`...). The map
      teaches that idea with setup → climax inside its width.
- R2. Every chunk requires the movement kit; no flat traversable ground
      (validated: exit never walk-reachable — kept from iteration 02).
- R3. The reachability model covers the FULL base kit (jump, double jump,
      dash, wall-jump chimneys) so chunks may REQUIRE any of it. Boon
      mobility stays un-modeled (fluidity/skips only).
- R4. Rooms escalate: the generator orders middle chunks by difficulty,
      easy first, hardest before the exit (climax), and starts every room
      with a scoping platform (beginning).
- R5. Difficulty tiers per mechanic: tier 1 teaches (wide margins, hazards
      punish lightly), tier 2 is standard, tier 3 stacks hazards and cuts
      margins. Deeper biomes draw from higher tiers.
- R6. Safety ledges: each chunk has at least one full-stop rest position
      (standable, no hazard adjacent) in its first half.
- R7. Enemies are placed on the problem (guarding the line the player wants),
      never as filler on dead ground.
- R8. Short rooms. 3-5 chunks. The exit is visible business, not a hike.

## Sources

- [Level Design Workshop: Designing Celeste — GDC talk (Maddy Thorson)](https://www.youtube.com/watch?v=4RlpMhBKNr0)
- [Lessons I've Learnt From Celeste's Level Design — Primed Pixel](https://primedpixel.co.uk/posts/lessons-ive-learnt-from-celestes-level-design/)
- [How to design breathtaking 2D platformer levels — Tadeas Jun](https://eledris.com/design-2d-platformer-levels/)
- [The Level Design of Dead Cells: a hybrid approach — Sébastien Bénard (deepnight.net)](https://deepnight.net/tutorial/the-level-design-of-dead-cells-a-hybrid-approach/)
- [Building the Level Design of a procedurally generated Metroidvania — Game Developer](https://www.gamedeveloper.com/design/building-the-level-design-of-a-procedurally-generated-metroidvania-a-hybrid-approach-)
- [Super Meat Boy's McMillen Explains 'Why So Hard?' — Game Developer](https://www.gamedeveloper.com/game-platforms/-i-super-meat-boy-i-s-mcmillen-explains-why-so-hard-)
- [Critical-Gaming Network — Super Meat Boy pt.3](https://critical-gaming.com/blog/2011/1/6/super-meat-boy-pt3.html)
