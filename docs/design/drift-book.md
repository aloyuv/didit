# Drift Book

A list of what the gaps are between the design and implementation.

## Build Order

The order in which we build the app, front to back, prioritizing the core loop
before polish and edge-case screens.

1. **Project setup** - Flutter scaffold, routing (go_router), state management
   (riverpod), SQLite with migrations
2. **Data model + schema** - trackers table, logs table, migrations
3. **Tracker Type screen** - create a tracker (habit vs goal, period, freeze
   config)
4. **Home screen** - view streak cards, tap card to log (the core loop);
   edit/undo icon buttons on each card
5. **Visual evaluation** - stop building, look at web ui, set up a github pages
   action so the web app can live on github.io
6. Try to build the android apk
7. Build a few tests
8. **Tracker Edit screen** - edit tracker config (name, period, unit, target,
   etc.) — done via `/habit-edit/:id` and `/goal-edit/:id`; accessible from the
   edit icon on each home card
9. **Celebrations** - particle effects and animations for completions and
   milestones
10. **Settings screen** - export and import data
11. **Mass Edit screen** - bulk-set a value across a date range
12. **Streak Calendar View** - browse and edit historical logs by date
13. **Streak freezes** - earn/spend freezes, freeze configuration in Streak Type
14. **Onboarding screen** - shown on first run with zero streaks

---

## Current Gaps

### Home Screen

- **Adaptive card layout** — always renders a 2-column grid. Design calls for: 1
  tracker → full screen, 2 → top/bottom split, 3–4 → quarters, 5+ → list rows.
- **"X days since last log"** — when a habit hasn't been logged in more than one
  cycle, the card should show how long ago it was done instead of the streak
  count. Not implemented.
- **Note button** — each card should have a button to attach a note to today's
  log. Not implemented.
- **Drag-to-reorder** — long-pressing a card should allow dragging it to a new
  position (updates `sortOrder`). Not implemented.

### Tracker Details Screen

- **Log-today buttons** — the design specifies buttons for each value option (or
  a single tap for binary habits, numeric entry for goals) directly on the
  details screen to log today's entry. Currently logging is only done from the
  home card or by tapping a calendar date.
- **Mass Edit button** — entry point to the Mass Edit screen. Not implemented
  (Mass Edit screen itself also doesn't exist).
- **Celebration customization UI** — per-tracker toggle for celebrations on/off,
  custom emoji picker. Not implemented.

### Tracker Create / Edit Screen

- **Delete button** — no way to delete a tracker. Should show a scary warning
  with double confirmation. Not implemented.
- **Celebration settings** — toggle enable/disable and per-tracker celebration
  emoji controls. The tracker emoji exists in the schema, but celebration
  enable/disable and picker UI are not implemented.
- **Streak freeze UI** — the schema has all the freeze fields, but the habit
  edit screen does not expose earn-interval, limit, or require-note config yet.
  The freeze toggle exists in the DB but no UI is wired up.

### Celebrations

- **Milestone tier** — only the "completion" tier (small particle burst) is
  implemented. No detection of milestone streak counts (3, 7, 14, 21, 30,
  …, 1000) or goal milestones (25%/50%/75% of target, round numbers). Not
  implemented.
- **Encouraging text** — "Nice!", "Keep it up!", "Logged!" overlay text after a
  log. Not implemented.
- **Sharing** — "Share" button after a milestone celebration to export a streak
  card image. Not implemented.
- **`confetti` package unused** — listed as a dependency; the current particle
  system is hand-rolled. Either wire up confetti for the milestone tier or
  remove the dependency.

### Streak Logic

- **Streak freezes (runtime)** — the schema stores freeze logs (`isFreeze=true`)
  and `habitFreezesAvailable`, but no logic earns freezes over time, lets the
  user spend one, or factors freeze logs into streak calculation. Not
  implemented.

### Settings Screen

- **Import confirmation modal** — the "wipe all data?" scary modal with tracker
  count preview before overwriting. Likely missing or incomplete.

### Missing Screens

- **Onboarding screen** — shown on first run with zero trackers. Currently the
  home screen shows a plain "No trackers yet" message with a button; the full
  welcome/onboarding flow is not implemented.

### Tests

- No tests exist yet. The tech-stack doc calls for "lots of tests (for
  functionality and celebrations)".
