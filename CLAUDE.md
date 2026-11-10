# CLAUDE.md — AI instructions for this repo

Offline Flutter task manager (entrance assignment, 3 h time box). Two screens: task list (search, priority + completion filters, complete/reopen/delete, activity timeline bottom sheet) and a create/edit form. Graded on decisions, structure, and how the AI is directed and verified — **not** feature count.

## Start of every session
1. Read `PLAN.md` (the source of truth: decisions, phases, handoff protocol) and run `git log --oneline` + `git status`.
2. Execute **only the first unchecked phase** in `PLAN.md §5`. Do not add features that are not in the plan; ask the human when something is ambiguous.
3. A phase is done only when `flutter analyze` has zero issues and `flutter test` is green. Then tick the tracker and commit with the exact message from the plan.

## Commands
- `flutter pub get` · `flutter analyze` · `flutter test`
- `flutter run` · `flutter run --dart-define=FAIL_WRITES=true` (all writes fail) · `--dart-define=FAIL_FIRST_WRITES=1` (first write fails, then recovers). Changing a dart-define needs a full restart, not hot reload.

## Architecture rules
- Feature-first: `lib/features/tasks/{domain,data,presentation}` + small `lib/core/`. Dependency direction: `presentation → domain ← data`. Package imports only (`always_use_package_imports`).
- `domain` is pure Dart: no Flutter, sqflite, or bloc imports. Real logic lives in pure functions (`TaskChangeDetector`, `TaskValidator`).
- Blocs/cubits depend on the `TaskRepository` interface only; they never import `data/`. Widgets never touch the repository or contain business logic.
- No UseCase classes. Repository returns `Result<T>` (`Success`/`Failed`); raw exceptions never leave `data/`.
- All SQL lives in `data/`.

## Data & consistency rules
- Every write is one `db.transaction`; task row and event row(s) are written inside the same transaction.
- Inside the transaction callback use the `txn` object only — never `db` (deadlock).
- `PRAGMA foreign_keys = ON` in `onConfigure` (cascade delete depends on it).
- Compute diffs against the row **read inside the transaction**, not against a UI snapshot. A no-change save executes zero statements.
- Complete/reopen takes a target (`setCompleted(id, bool)`) and is idempotent inside the transaction.
- Emit `changes` only after commit, and only if something changed.
- Schema version = `kMigrations.length`; never wipe data on downgrade.

## State rules
- States and events are immutable `Equatable`s with **complete** `props`.
- Loading, empty, success, and error states must all be represented.
- Transient errors carry an incrementing token so identical consecutive errors still trigger the listener.
- Search is debounced + `restartable()`; mutations are `sequential()`; stale results are dropped by checking `state.query`.
- Dispose everything you open: controllers, focus nodes, stream subscriptions (in `close()`), stream controllers, the database. Minimise rebuilds (`buildWhen`, `BlocSelector`, `const`, keyed list items). `setState` only for ephemeral UI.

## Testing
- Focused tests on the riskiest logic, no coverage chase: change detection, atomic rollback, no-op writes, idempotent completion under concurrency, stale-query handling, failure + retry.
- Data tests use real in-memory SQLite (`sqflite_common_ffi`, `inMemoryDatabasePath`, `singleInstance: false`). Bloc tests use hand-written fakes with `Completer`s, not timers.

## Git & workflow
- One commit per phase, English imperative messages as written in `PLAN.md`. Never squash, amend, or rebase earlier commits. Keep any `Co-Authored-By` trailer.
- When the AI makes a real mistake, append it to `AI_WORKFLOW.md → Running log` (what happened, how it was caught, fix commit). Never invent entries.
- Docs and code comments are in English.
