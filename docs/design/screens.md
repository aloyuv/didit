# Screens

## Home

Streak cards - if you have 1 streak it's full screen, 2 splits top/bottom, 3-4 splits into quarters, 5+ shows each streak as a row. Each card shows:

- Done today or not (hinted visually, not text)
- Current streak or total (shows yesterday's value, updates after done). Shows "X days since last log" instead of streak number when not done in more than one cycle.
- Button to set the enum value
- Button to set a note
- Button to go to Streak Details screen

Bottom navigation row with icons:

- Settings screen
- Home screen
- "+" add a new streak → Streak Type screen

## Streak Details

- Current streak status in big font
- Buttons for all enum values to modify today
- Button - Mass Edit
- Button - Change Streak Type
- Celebration settings
  - Toggle - enable/disable
  - Random emoji (when disabled, shows "Emoji set" text box for customizing celebration particles)
- Button - Calendar View
- Button - Delete (scary warning with double confirmation)
- List of recent logs with time, date, and value

## Streak Calendar View

Calendar widget where you can navigate to a specific year/date and see or edit the streak value on that date.

## Settings

- Export button
- Import button (loads file, shows how many streaks, big scary "wipe all data?" modal)
- App version
- Link to GitHub

## Mass Edit

- Start date selector
- End date selector
- Value selector (enum values or number, depending on streak type)
- Button - Save
- Button - Cancel

## Streak Type

Select streak kind:

- **Options** - each log has a specific value like "did it", "did not", "streak freeze", or 1-5 for mood
- **Amount** - each log has a numeric value

Select duration (see [data model](data-model.md#duration)).

Configure streak freezes (see [data model](data-model.md#streak-freezes)).

## Onboarding (First Run)

Shown only when the user has zero active streaks.

Core message: "Welcome! Start tracking your first milestone in 30 seconds."

Call to action: A prominent centered "+" button or "Create your first streak" button that leads directly to the Streak Type screen.
