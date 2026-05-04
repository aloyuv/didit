# Screens

## Tracker Types & Input Modes

**Tracker types (design terminology):**

- **Periodic Habit** – one log per period (day, week, etc.); streak-based.
  Previously called just "Habit."
- **Anytime Habit** – unlimited logs per period; event-based count. Not
  streak-based.

**Value input modes:**

- **Toggle** – few options (≤3). Tapping cycles through values inline without
  opening a dialog.
- **Pick** – many options (>3). Always opens a dialog to choose a value.

K = 3, matching the `habitValueOptionsCycleMax` constant in code.

---

## Tap & Long-Press Behavior

The rules below apply identically to home screen cards and the calendar day
view.

| State                                | Toggle (≤K options)                                   | Pick (>K options)                                     |
| ------------------------------------ | ----------------------------------------------------- | ----------------------------------------------------- |
| Periodic Habit, unlogged             | tap cycles in (logs immediately)                      | tap opens value picker                                |
| Periodic Habit, logged, mid-cycle    | tap cycles to next value                              | —                                                     |
| Periodic Habit, logged, end of cycle | tap opens value picker + delete                       | tap opens value picker + delete                       |
| Anytime Habit, unlogged              | tap opens value picker                                | tap opens value picker                                |
| Anytime Habit, logged                | tap opens: Add new / Update (→ value picker + delete) | tap opens: Add new / Update (→ value picker + delete) |

**Long press** on any entry (home screen card or calendar day) opens the full
log editor (notes, timestamps, etc.).

**Key implications:**

- Cycling exists for Periodic Habit toggles on both surfaces, but reaching the
  end of the cycle opens a dialog (rather than silently clearing the entry).
- Anytime Habit tap behavior is always a dialog regardless of Toggle or Pick,
  because the app cannot distinguish "change value" from "add new entry" from a
  tap alone.

---

## Home

Tracker cards - if you have 1 tracker it's full screen, 2 splits top/bottom, 3–4
splits into quarters, 5+ shows each tracker as a row. Each card shows:

- Done today or not (hinted visually, not text)
- **Periodic Habit**: current streak count (shows yesterday's value, updates
  after done). Shows "X days since last log" instead of streak number when not
  done in more than one cycle.
- **Goal**: running total, with a progress bar toward the target if one is set.
- Button to set a note
- Button to go to Tracker Details screen

Tap and long-press behavior on cards follows the shared rules defined in
[Tap & Long-Press Behavior](#tap--long-press-behavior).

Trackers can be reordered with the triple-dot menu (move up or down options).

Bottom navigation row with icons:

- Settings screen
- Home screen
- "+" add a new tracker → Tracker Type screen

## Tracker Details

- Current status in big font (streak count for Habits; running total for Goals)
- **Habit**: buttons for all value options to log today's entry, or a single tap
  for binary habits
- **Goal**: numeric entry (or a single tap for fixed-step goals) to log a new
  entry
- Button - Mass Edit
- Button - Edit Tracker (goes to Tracker Edit for change name, type settings,
  freeze config)
- Button - Calendar View
- List of recent log entries with time, date, and value

## Tracker Create or Edit

### Common settings

- Name (required)
- Emoji (optional, stored separately from the name)
- Celebration settings
  - Toggle - enable/disable
  - Random emoji (when disabled, shows "Emoji set" text box for customizing
    celebration particles)
- Button - Delete (scary warning with double confirmation)

### Create or edit habit

Edit all the common tracker settings.

Select period (see [data model](data-model.md#schedule)).

Configure value options: leave empty for a binary habit, or add ordered labels
(e.g. "1 / 2 / 3 / 4 / 5" for mood).

Configure streak freezes (see [data model](data-model.md#streak-freezes)).

### Create or edit Goal

Edit all the common tracker settings.

- Unit (optional) - what the number measures (e.g. km, meters, books)
- Target amount (optional) - the number to reach
- Target date (optional) - deadline to reach the target
- Step size (optional) - fixed amount added per log; free-form entry if absent

## Tracker Calendar View

Calendar widget where you can navigate to a specific year/date and see or edit
the log value on that date. Tap and long-press behavior on calendar day cells
follows the same shared rules as home screen cards — see
[Tap & Long-Press Behavior](#tap--long-press-behavior).

## Settings

- Back up data button
- Restore from backup button (loads file, shows how many trackers, big scary
  "wipe all data?" modal)
- App version
- Link to GitHub

## Mass Edit

- Start date selector
- End date selector
- Value selector (enum values or number, depending on tracker type, also
  possible to clear the date range)
- Button - Save
- Button - Cancel

## Tracker Type

Two sections: **Templates** (above) and **Custom** (below).

### Templates

Compact tappable cards that pre-fill the relevant edit screen so the user only
needs to confirm or tweak. Examples:

- **Daily cardio** – daily habit with (Run, Bike, Swim) options
- **Track mood daily** – daily habit with 5 value options (1–5)
- **Swim 50 km this year** – goal, unit "km", target 50, target date Dec 31 of
  the current year

### Custom

- **Habit** - do repeatedly on a schedule; each log is binary ("done") or a
  rating (e.g. 1–5 for mood); the streak count is tracked. Tapping this will
  open the Habit edit screen with no pre-filled values.
- **Goal** - accumulate toward a target; each log adds to a running total (e.g.
  meters swum, books read). Tapping this will open the Goal edit screen with no
  pre-filled values.

## Onboarding (First Run)

Shown only when the user has zero active trackers.

Core message: "Welcome! Start tracking your first milestone in 30 seconds."

Call to action: A prominent centered "+" button or "Create your first tracker"
button that leads directly to the Tracker Type screen.

## Implementation files

- [router.dart](../../app/lib/router.dart)
- [home_screen.dart](../../app/lib/features/home/home_screen.dart)
- [tracker_details_screen.dart](../../app/lib/features/tracker_details/tracker_details_screen.dart)
- [mass_edit_screen.dart](../../app/lib/features/tracker_details/mass_edit_screen.dart)
- [tracker_type_screen.dart](../../app/lib/features/tracker_type/tracker_type_screen.dart)
- [habit_edit_screen.dart](../../app/lib/features/tracker_type/habit_edit_screen.dart)
- [goal_edit_screen.dart](../../app/lib/features/tracker_type/goal_edit_screen.dart)
- [settings_screen.dart](../../app/lib/features/settings/settings_screen.dart)
