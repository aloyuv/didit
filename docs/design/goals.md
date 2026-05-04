# Goals

- Track daily recurring tasks like run, duolingo, journal, sentiment.
- Track progress towards goals like "swim 10km this year"
- Celebrate milestones
- Make it easy to log (single tap for 90% of use cases)
- Make it easy to import, export, and mass edit data

## Terminology

- Tracker - a thing you do; either a Habit or a Goal
- Habit - a tracker for recurring tasks where consistency (streak) is the goal
- Goal - a tracker for accumulating. Toward a target or just to make the number
  bigger.
- Log entry - one recorded instance for a tracker

## Design principles

- Make it easy and clear - have big click targets, big fonts, show the streak
  proudly, like this app is a place to track and celebrate progress towards
  recurring goals and tasks.
- Make it satisfying - celebrate with the user in visually rewarding ways,
  typography, particle effects, animations, colors. Encourage to take
  screenshots and share.
- Encourage to get back in the game - show how long ago I haven't done X, or how
  much I need to do to catch up with my target pace.
- Fast - the UI should feel instant and local. Never rely on a blocking sync to
  cloud for any functionality.
- Simple - the app should allow some power user configuration, but hidden under
  extra buttons that uncover the mess. Offer sane defaults that are easy to set
  up for the core use-cases mentioned in the goals.
- Open source - MIT license. Free on the app stores. There is no login or cloud
  cost.
- This is a mobile app, so designed for portrait mode. The web desktop version
  will be in a column.

## Implementation files

- [main.dart](../../app/lib/main.dart)
- [theme.dart](../../app/lib/theme.dart)
- [home_screen.dart](../../app/lib/features/home/home_screen.dart)
- [mass_edit_screen.dart](../../app/lib/features/tracker_details/mass_edit_screen.dart)
- [settings_screen.dart](../../app/lib/features/settings/settings_screen.dart)
