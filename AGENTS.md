Write code that is easy for others (and future you) to understand and modify.
Keep functions small and focused on a single responsibility, and split any
function that becomes long or mixes concerns. Prefer clarity over cleverness,
using precise, domain-specific names and straightforward control flow. When
logic is not immediately obvious—due to business rules, edge cases, or
non-trivial transformations—add brief comments that explain _why_ the code
exists and the assumptions behind it, rather than restating what it does. Avoid
unnecessary abstraction, hidden side effects, and generic “helper” patterns that
obscure intent. Make invalid states hard to represent, handle errors explicitly
and early, and ensure behavior is covered by tests. Every change should leave
the codebase easier to read and safer to extend than before.

This is an offline-first app, everything should feel snappy and fast.

While implementing a feature, please keep teh docs/design/\*.md files in mind
and rely on them to guide your implementation, or fix them if they're wrong.

Flutter commands in this workspace need to run outside the sandbox. Use
escalation for commands like `flutter test`, `flutter analyze`, and Dart
formatting; the sandbox can block Flutter SDK/cache or telemetry file access and
cause those commands to hang or fail even when the code is fine.
