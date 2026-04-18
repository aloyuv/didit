# Data Model

## Tracker

A tracker is one thing you want to follow over time. There are two kinds:

- **Habit** - something you do repeatedly on a schedule, where consistency is
  the goal. Each log is a discrete value like "did it", "skipped", or a rating
  (1-5 for mood).
- **Goal** - something you accumulate toward a target. Each log adds to a
  running total (e.g. meters swum, pages read, jobs applied, etc.).

### Habit - schedule

How often the habit is expected to be logged:

- Once a day
- Once a week
- Once a month
- Any time

Toggle: **allow multiple logs per period** — e.g. logging mood several times a
day, or multiple runs in one day.

### Habit - Streak Freezes

- Toggle - enable/disable
- Earn a freeze once every [7] days (editable)
- Limit up to [2] streak freezes accumulated (editable)
- Toggle - require a note when using a freeze

### Goal - target

- **Target amount** — the number you are working toward (e.g. 50,000 meters)
- **Unit** — what the number measures (e.g. meters, pages, kg)
- **Target date** (optional) — a deadline by which you want to reach the target

### Milestones

Milestones mark meaningful points along the way. When a log pushes the running
total past a milestone, the app celebrates it.

Each milestone has:

- **Threshold** — the amount at which it triggers (e.g. 25,000 meters)
- **Label** (optional) — a name to show when it is reached (e.g. "Halfway
  there!")

Milestones are detected automatically (e.g. at 25%, 50%, 75%, and 100% of the
target, and at round numbers like 10km out of 100km, or interesting numbers like
111km out of 1000km).

## Log entry

Every log entry records:

- **Logged at** — when the entry was created
- **Last edited at** — when the entry was last changed
- **Tracker** — which tracker this entry belongs to
- **Value** — "did it" / "skipped" / rating for Habits; a number for Goals
- **Note** (optional) — free text, e.g. an excuse, a detail, or how it felt

## Denormalized fields

These values are derived from log entries but stored directly on the Tracker row
for fast display without recomputing every time:

- **Current streak** (Habits) — number of consecutive periods with a completed
  log
- **Longest streak** (Habits) — all-time best streak
- **Running total** (Goals) — sum of all logged values so far
- **Freezes available** (Habits with freezes enabled) — how many freezes the
  user currently holds
