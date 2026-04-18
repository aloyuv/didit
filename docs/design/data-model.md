# Data Model

## Streak

A streak can be of a few kinds:

- **Options** - each log has a specific value like "did it", "did not", or
  "streak freeze". Or 1-5 for mood.
- **Amount** - each log has a numeric value (e.g. meters, weight, pages)

### Duration

How often a streak is logged. One of:

- Once a day
- Once a week
- Once a month
- Any time

Also toggle "allow multiple completions" which means eg you might want to log
your mood or run multiple times in a day.

### Streak Freezes

Only relevant to Options type streaks.

- Toggle - enable/disable
- Earn a freeze once every [7] days (editable)
- Limit up to [2] streak freezes (editable)
- Toggle - require a note

## Streak log

Every log has a:

- Created At Timestamp
- Modified At Timestamp
- Foreign key to Streak
- Option value (for Options type streaks)
- Amount value (for Amount type streaks)
- Note - free text to attach, like an excuse or detail about what happened that
  log
