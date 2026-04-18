# Visual Effects

Marking a task as done or hitting a milestone should feel like a big deal.
Celebrations should feel responsive and never be blocked by the data storage
process - trigger the animation immediately, persist in the background.

## Triggers

Two tiers of celebration:

- **Completion** - any successful log. Subtle burst of particles, brief
  encouraging text ("Nice!", "Keep it up!", "Logged!").
- **Milestone** - hitting a notable number. Full-screen particle shower, larger
  text, longer duration.

## Interesting numbers

### Habit milestones (streak count)

Example streak lengths that trigger a milestone celebration:

3, 7, 14, 21, 22, 30, 33, 50, 55, 60, 66, 75, 77, 88, 99, 100, 150, 200, 250,
365, 500, 1000, 1111

### Goal milestones

- Reaching the `GoalTargetAmount` (if set) - the biggest celebration
- Round numbers that are multiples of a "nice" step relative to the target (e.g.
  25%, 50%, 75% of target if a target is set; or 10 / 50 / 100 / 500 / 1000 /
  5000 if no target is set)

### Other numbers

The above is not an exhaustive list. The code should figure out what the above
special numbers kind of look like, the patterns, and celebrate whenever we hit
something that looks like a milestone number. It's better to celebrate too much
than too little. For example "64" and "256" aren't mentioned but are special for
nerds so could have flavor text "I love the Nintendo 64!" or other creative
ideas.

## Particle customization

On the Tracker Details screen the user can:

- Toggle celebrations on/off per tracker
- Use a random emoji for particles (default)
- Set a specific emoji to use as the particle (e.g. 🏃 for a running habit)

## Sharing

After a milestone celebration, show a "Share" button that lets the user
screenshot and share their streak card (pre-composed with the streak number and
tracker name in a shareable format).
