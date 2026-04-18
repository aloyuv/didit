# Build Order

The order in which we build the app, front to back, prioritizing the core loop
before polish and edge-case screens.

1. **Project setup** — Flutter scaffold, routing (go_router), state management
   (riverpod), SQLite with migrations
2. **Data model + schema** — streaks table, logs table, migrations
3. **Streak Type screen** — create a streak (options vs amount, duration)
4. **Home screen** — view streak cards, mark a streak done (the core loop)
5. **Visual evaluation** - stop building, look at web ui, try to build an
   android apk
6. Build a few tests
7. **Streak Details screen** — full status view, edit today's value, recent logs
   list
8. **Celebrations** — particle effects and animations for completions and
   milestones
9. **Settings screen** — export and import data
10. **Mass Edit screen** — bulk-set a value across a date range
11. **Streak Calendar View** — browse and edit historical logs by date
12. **Streak freezes** — earn/spend freezes, freeze configuration in Streak Type
13. **Onboarding screen** — shown on first run with zero streaks
