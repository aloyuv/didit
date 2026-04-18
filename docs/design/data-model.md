# Data Model

This data model is for the phone app's sqlite database.

## Tracker

A tracker is one thing you want to follow over time. There are two kinds:

- **Habit** - something you do repeatedly on a schedule, where consistency is
  the goal. Each log is a discrete value like "did it", "skipped", or a rating
  (1-5 for mood).
- **Goal** - something you accumulate. Toward a target or just to make the
  number bigger. Each log adds to a running total (e.g. meters swum, pages read,
  jobs applied, books finished).

### Tracker entry

Every tracker has:

- **Name** — a short label chosen by the user (e.g. "Morning run", "Mood")
- **Type** — Habit or Goal
- **HabitDuration** — how often the tracker is expected to be logged
- **GoalTarget** — the number you are working toward
- **HabitValueOptions** — a list of values the user can choose from
- **Archived** — hide the tracker without deleting its history
- **Created at** — timestamp of when the entry was actually created
- **Modified at** — timestamp of when the entry was last modified

Denormalized derived fields:

- **HabbitStreak** — number of consecutive periods with a completed log
- **HabbitLongestStreak** (Habits) — all-time best streak
- **HabitFreezesAvailable** (Habits with freezes enabled) — how many freezes the
- **GoalRunningTotal** (Goals) — sum of all logged values so far user currently
  holds

These values are derived from log entries but stored directly on the Tracker row
for fast display without recomputing every time:

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

- **Unit** — what the number measures (e.g. meters, pages, kg, books)
- **Target amount** (optional) — the number you are working toward (e.g. 50,000
  meters). Optional because a user might just want to track their amount with no
  plan.
- **Target date** (optional) — a deadline by which you want to reach the target
- **Step size** (optional) — if set, each log adds this fixed amount instead of
  a free-form number. Use this for counting discrete items like books (step = 1)
  where typing "1" every time would feel awkward.

## Log entry

Every log entry records:

- **Log date** — the date the activity happened (not necessarily when it was
  logged; the user can backfill yesterday's run today)
- **Created at** — timestamp of when the entry was actually created
- **Modified at** — timestamp of when the entry was last modified
- **Tracker** — which tracker this entry belongs to
- **Value** — position in the value options list (Habits); a number (Goals)
- **Note** (optional) — free text, e.g. an excuse, a detail, or how it felt
