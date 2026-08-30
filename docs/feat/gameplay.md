# Glass Pulse gameplay

> updated 2026-08-30 · pre-release

Product direction: [product.md](../biz/product.md). Architecture: [architecture.md](../arch/architecture.md).

## Invariant control

Every shipping mode uses one controlled ball on one orbit. The ball moves automatically; the first tap starts a run and every later gameplay tap reverses direction immediately. Collision with a hazard is fatal. Pause freezes every timer and ignores board taps until Resume resets the frame clock.

## Classic

Classic preserves the original deterministic rules and is the regression oracle:

1. Gem collection awards one point.
2. Every third point adds an obstacle until three exist.
3. Later three-point milestones multiply obstacle speed by 1.04.
4. Gem spawn retries safe angles and falls back to maximum obstacle clearance.

## Rush 60

- Session duration: 60 seconds.
- Consecutive gem collections raise a capped combo multiplier.
- Collision ends the run; reaching 60 seconds completes it.
- HUD shows remaining seconds and combo.

## Precision Pulse

- Gem collection succeeds only while the pulse window is active.
- Missing an inactive pulse resets combo without awarding score.
- Pulse state is communicated by scale/shape plus color.
- Precision alone receives continuous proximity haptics; Classic difficulty is not reduced by haptic guidance.

## Wave Survival

- Five deterministic waves, eight seconds per wave.
- Wave transitions add hazards only through the same safe-spawn clearance used by the engine.
- At the obstacle cap, later waves increase obstacle speed instead of adding another ball or engine.
- Clearing the final wave completes the run.

## Daily Challenge

- Daily key uses the local calendar date; seed includes ruleset version so the same day/version reproduces the same challenge.
- Rotation uses Classic, Rush, Precision and Wave rule sets.
- Rush keeps its 60-second completion; Wave keeps final-wave completion; Daily Classic/Precision use a 60-second completion window.
- Daily streak, Daily best and the first-clear shard bonus update only after `GameRunOutcome.completed`; a collision cannot earn the clear bonus.
- The first-clear bonus is keyed by day and cannot be farmed by replaying the same Daily.
- Rankings are local only until a real Game Center/backend exists.

## Access

- Free production: Classic + Daily Challenge.
- Plus production: Rush 60 + Precision Pulse + Wave Survival, unlocked only from verified StoreKit entitlement.
- Unsigned CI Beta: all modes/themes open through the compile-time Beta channel; no purchase state is persisted.
- Mode cannot change during an active or paused run.

## Feedback

- Reverse: fixed light impact + short low procedural tone.
- Gem: fixed rigid impact + bright cached tone + expanding ring.
- Collision: error haptic + low cached tone + red flash.
- Precision proximity: reusable Core Haptics continuous player, intensity/sharpness mapped from angular proximity and throttled to at most 25 updates/sec; stops outside the useful window or while paused/backgrounded.

## Fairness and determinism

Seeded randomness controls obstacle/gem placement. Initial and newly added obstacles stay clear of the ball; gem placement cannot loop forever. The automated stress test checks 10,000 seeded initial scenarios. Device frame rate, power and Dynamic Island behavior are not gameplay-rule evidence and remain separate device gates.
