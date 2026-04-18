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
4. **Home screen** - view streak cards, mark a streak done (the core loop)
5. **Visual evaluation** - stop building, look at web ui, set up a github pages
   action so the web app can live on github.io
6. Try to build the android apk
7. Build a few tests
8. **Tracker Details screen** - full status view, edit today's value, recent
   logs list
9. **Celebrations** - particle effects and animations for completions and
   milestones
10. **Settings screen** - export and import data
11. **Mass Edit screen** - bulk-set a value across a date range
12. **Streak Calendar View** - browse and edit historical logs by date
13. **Streak freezes** - earn/spend freezes, freeze configuration in Streak Type
14. **Onboarding screen** - shown on first run with zero streaks
