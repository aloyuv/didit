# Data Model

## Tracker

A tracker is one thing you want to follow over time. There are two kinds:

- **Habit** - something you do repeatedly on a schedule, where consistency is
  the goal. Each log is a discrete value like "did it", "skipped", or a rating
  (1-5 for mood).
- **Goal** - something you accumulate toward a target. Each log adds to a
  running total (e.g. meters swum, pages read, jobs applied, books finished).

Every tracker has:

- **Name** — a short label chosen by the user (e.g. "Morning run", "Mood")
- **Archived** — hide the tracker without deleting its history

### Habit

#### Value options

Each log records one value from a fixed list attached to the habit. The list is
ordered; values are referenced by position (0, 1, 2, …). Examples:

- Did it / Skipped
- Did it / Skipped / Streak freeze
- 1 / 2 / 3 / 4 / 5 (mood)

#### Schedule

How often the habit is expected to be logged:

- Once a day
- Once a week
- Once a month

Toggle: **allow multiple logs per period** — e.g. logging mood several times a
day, or multiple runs in one day.

#### Streak Freezes

- Toggle - enable/disable
- Earn a freeze once every [7] days (editable)
- Limit up to [2] streak freezes accumulated (editable)
- Toggle - require a note when using a freeze

### Goal

#### Target

- **Target amount** (optional) — the number you are working toward (e.g. 50,000
  meters). Optional because a user might just want to track their amount with no
  plan.
- **Unit** — what the number measures (e.g. meters, pages, kg, books)
- **Target date** (optional) — a deadline by which you want to reach the target
- **Step size** (optional) — if set, each log adds this fixed amount instead of
  a free-form number. Use this for counting discrete items like books (step = 1)
  where typing "1" every time would feel awkward.

## Log entry

Every log entry records:

- **Log date** — the date the activity happened (not necessarily when it was
  logged; the user can backfill yesterday's run today)
- **Logged at** — timestamp of when the entry was actually created or last
  edited
- **Tracker** — which tracker this entry belongs to
- **Value** — position in the value options list (Habits); a number (Goals)
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
