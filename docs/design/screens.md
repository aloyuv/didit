# Screens

## Home

Tracker cards — if you have 1 tracker it's full screen, 2 splits top/bottom, 3–4 splits into quarters, 5+ shows each tracker as a row. Each card shows:

- Done today or not (hinted visually, not text)
- **Habit**: current streak count (shows yesterday's value, updates after done). Shows "X days since last log" instead of streak number when not done in more than one cycle.
- **Goal**: running total, with a progress bar toward the target if one is set.
- Button to set the value (enum options or numeric entry, depending on tracker type)
- Button to set a note
- Button to go to Tracker Details screen

Trackers can be reordered by long-pressing a card and dragging it to a new position.

Bottom navigation row with icons:

- Settings screen
- Home screen
- "+" add a new tracker → Tracker Type screen

## Tracker Details

- Current status in big font (streak count for Habits; running total for Goals)
- **Habit**: buttons for all value options to log today's entry, or a single tap for binary habits
- **Goal**: numeric entry (or a single tap for fixed-step goals) to log a new entry
- Button - Mass Edit
- Button - Edit Tracker (change name, type settings, freeze config)
- Celebration settings
  - Toggle - enable/disable
  - Random emoji (when disabled, shows "Emoji set" text box for customizing celebration particles)
- Button - Calendar View
- Button - Delete (scary warning with double confirmation)
- List of recent log entries with time, date, and value

## Tracker Calendar View

Calendar widget where you can navigate to a specific year/date and see or edit the log value on that date.

## Settings

- Export button
- Import button (loads file, shows how many trackers, big scary "wipe all data?" modal)
- App version
- Link to GitHub

## Mass Edit

- Start date selector
- End date selector
- Value selector (enum values or number, depending on tracker type)
- Button - Save
- Button - Cancel

## Tracker Type

Select tracker kind:

- **Habit** — do repeatedly on a schedule; each log is binary ("done") or a rating (e.g. 1–5 for mood); the streak count is tracked
- **Goal** — accumulate toward a target; each log adds to a running total (e.g. meters swum, books read)

Select period (see [data model](data-model.md#schedule)).

Configure streak freezes (see [data model](data-model.md#streak-freezes)).

## Onboarding (First Run)

Shown only when the user has zero active trackers.

Core message: "Welcome! Start tracking your first milestone in 30 seconds."

Call to action: A prominent centered "+" button or "Create your first tracker" button that leads directly to the Tracker Type screen.
