# Drift Book

Remaining gaps between the design and implementation.

## Home Screen

- **Adaptive card layout** — renders a 1–2 column grid based on orientation.
  Design calls for: 1 tracker → full screen, 2 → top/bottom split, 3–4 →
  quarters, 5+ → list rows.
- **"X days since last log"** — when a habit hasn't been logged in more than one
  cycle, the card should show how long ago it was done instead of the streak
  count.
- **Drag-to-reorder** — long-pressing a card should allow dragging it to a new
  position (updates `sortOrder`). Move-up/down menu items exist as a workaround.

## Tracker Create / Edit Screen

- **Celebration settings** — per-tracker toggle (enable/disable) and custom
  celebration emoji picker. The tracker emoji field exists in the schema but the
  picker UI is not implemented.

## Celebrations

- **Milestone tier** — no detection of milestone streak counts (3, 7, 14, 21,
  30, …, 1000) or goal milestones (25%/50%/75% of target, round numbers). Every
  log gets the same small particle burst.
- **Encouraging text** — "Nice!", "Keep it up!", "Logged!" overlay text after a
  log.
- **Sharing** — "Share" button after a milestone celebration to export a streak
  card image.
- **`confetti` package unused** — listed as a dependency; the current particle
  system is hand-rolled. Either wire up confetti for the milestone tier or
  remove the dependency.

## Streak Logic

- **Streak freezes (runtime)** — the schema stores freeze logs (`isFreeze=true`)
  and `habitFreezesAvailable`, but no logic earns freezes over time, lets the
  user spend one, or factors freeze logs into streak calculation.

## Missing Screens

- **Onboarding screen** — shown on first run with zero trackers. Currently the
  home screen shows a plain "No trackers yet" message with a button.
