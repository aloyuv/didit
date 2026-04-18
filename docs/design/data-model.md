# Data Model

## Streak

A streak can be of a few kinds:

- **Options** - each log has a specific value like "did it", "did not", or "streak freeze". Or 1-5 for mood.
- **Amount** - each log has a numeric value (e.g. meters, weight, pages)

Every streak log has:

- Created At Timestamp
- Modified At Timestamp
- Note - free text to attach, like an excuse or detail about what happened that log

## Duration

How often a streak is logged. One of:

- Once a day
- Once a week
- Once a month
- Any time

## Streak Freezes

Only relevant to Options type streaks.

- Toggle - enable/disable
- Earn a freeze once every [7] days (editable)
- Limit up to [2] streak freezes (editable)
- Toggle - require a note
