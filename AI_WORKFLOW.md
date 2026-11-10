# AI Workflow

## Tools
- Claude Code (VS Code extension) on Linux; Flutter 3.44.6. The Claude model varied between sessions (implementation session and a later independent review session).

## How I split the work
- **Plan first:** I gave the assignment to the AI and had it write `PLAN.md` (decision log, 10 phases, exact commit messages, handoff protocol) and `CLAUDE.md` (rules) *before* any code. Any agent can resume from the first unchecked phase.
- **One phase per prompt, one commit per phase;** each phase gates on `flutter analyze` (strict mode) + `flutter test`.
- **Riskiest first:** pure domain logic and the atomic SQLite repository (rollback, idempotency, cascade) were built and tested before bloc and UI.
- **Independent review pass:** after the implementation I asked the AI to review the whole project against the assignment; it produced `REVIEW_FIXES.md`, which was executed as phases F1–F5.

## Key prompts
1. *"This is a raw Flutter project … based on the email, create an md file with development phases, exact implementation steps, and an English commit message per phase so another AI agent can continue."* → `PLAN.md`
2. *"Read PLAN.md and CLAUDE.md, start from the first phase, implement the tasks and commit every phase."* (original: Persian)
3. *"Review the whole project and write everything that needs fixing or improving into an md file I can give to an AI agent."* → `REVIEW_FIXES.md`

## Where the AI was wrong (found by the review pass, fixed in later commits)
1. **Fault counter race (`b840948`).** `FAIL_FIRST_WRITES=N` used one shared counter read at checkpoint time; with two concurrent writes and N=1, *no* write failed. All tests were green because they used a different test injector and `ConfiguredFault` (the real one) had no tests. Caught by reading the code and a throw-away probe test; fixed with per-operation `WriteAttempt` + tests.
2. **Duplicate error SnackBars (`c69289d`).** The form's `BlocListener` had no `listenWhen`, so after a failed save every priority change re-showed the error. Caught by reading; regression widget test added.
3. **Emit after close / notify after dispose (`c69289d`, `e4e69f4`).** Cubits emitted after `await` without `isClosed` checks, and the repository pushed to a closed `changes` controller after commit (could report a committed write as failed). Caught by reading; guards added.
4. **Raw exception text in the UI (`e4e69f4`).** `StorageFailure(error.toString())` leaked `DatabaseException(...)` to users; now friendly messages, details logged.

## What I verified myself
Manually checked on an Android device (Pixel 8 Pro emulator) following the checklist in `PLAN.md` P7; everything behaved as expected:
- [x] Persistence after kill/relaunch
- [x] `FAIL_WRITES=true`: errors shown, list unchanged, no partial data after relaunch
- [x] `FAIL_FIRST_WRITES=1`: Retry succeeds with exactly one event
- [x] 10 rapid Complete taps → one `Completed` event
- [x] Fast typing + combined filters preserved after an edit

Automated evidence (not manual): 62 tests incl. real-SQLite rollback, no-op `total_changes()`, concurrency, stale-query and integration tests.

Full running log: [docs/ai-running-log.md](docs/ai-running-log.md).
