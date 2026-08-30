# Glass Pulse gameplay

> updated 2026-08-30 · pre-release

Product direction: [product.md](../biz/product.md).

## Core loop

1. The ball starts at the top of one circular orbit and moves at constant angular speed.
2. The first tap starts the run; each later tap instantly reverses direction.
3. Obstacle arcs rotate around the same orbit at their own speeds; angular overlap ends the run.
4. A gem spawns outside every obstacle margin; crossing it awards one point and immediately spawns the next gem.
5. At every third point, the game adds an obstacle until three exist; later three-point milestones multiply all obstacle speeds by 1.04.

## Fairness

Initial and newly added obstacles spawn away from the ball. Gem placement retries random safe angles and falls back to the angle with the greatest obstacle clearance, so spawning cannot loop forever.

## Feedback

- Reverse: light impact and short low tone
- Gem: rigid impact, bright tone, expanding ring
- Collision: error haptic, low tone, red flash
- Orbit: visual radius breathes with a theme-specific sine pulse; collision rules remain angular and do not change with the visual pulse
