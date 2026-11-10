# REVIEW_FIXES.md — Post-implementation review: fixes & improvements

Review of the finished implementation (commits up to `a8dfa4d`). Baseline verified: `flutter analyze` → 0 issues, `flutter test` → 53 passed, `dart format` clean. Everything below is what the green checks do **not** catch.
Items marked **[confirmed]** were reproduced with a throw-away probe test; **[by reading]** follow directly from the code.

> Grading reminder: engineering decisions + honest AI workflow matter more than features. Prefer a few well-tested fixes over many edits. Documentation honesty (Phase F5) is worth as much as any code fix.

---

## 0. Handoff protocol (same rules as `PLAN.md §1`)

1. Read `CLAUDE.md`, `PLAN.md`, this file; run `git log --oneline` and `git status`.
2. Execute the **first unchecked phase** in §2 only. Write the failing test first when the phase says so.
3. Done = `flutter analyze` 0 issues + `flutter test` green + `dart format --set-exit-if-changed lib test` clean.
4. Tick the phase in §2 inside its commit; use the exact commit message. **Never** rewrite/squash existing history (two commits are already titled "docs: add phased implementation plan" — leave them).
5. Any bug in this list that you fix **is a real AI mistake found by review** → append it to `AI_WORKFLOW.md → Running log` (what, how caught = "independent review pass", fix commit). Do not invent anything beyond this list.
6. Phases marked **HUMAN INPUT** need facts only the human has (real times, tools used, what they verified). **Ask; never fabricate.**

---

## 1. Findings

### High — correctness / requirement risk

| ID | Where | Problem | Evidence |
|---|---|---|---|
| H1 | `data/fault/write_fault_injector.dart:26-54`, `datasources/task_local_datasource.dart` (`beginWrite()` calls) | `FAIL_FIRST_WRITES=N` is racy and miscounted: `_writeCount` is **shared mutable state** read at *checkpoint* time, so with 2 concurrent writes and N=1 the counter is already 2 when the first op checks → **no write fails**. Also no-op writes (`Unchanged`) consume the budget. The "reproducible failure + retry" requirement (R10) is the reviewers' demo path. `ConfiguredFault` has **zero tests**. | **[confirmed]** two concurrent `create` with `failFirstWrites: 1` → 0 failures (expected 1) |
| H2 | `presentation/form/view/task_form_page.dart:71-83` | `BlocListener` has no `listenWhen`. After a failed save, changing the priority (`priorityChanged` emits a new state that still has `status == failure`) fires the listener again → **duplicate error SnackBars** on every unrelated state change. | **[by reading]** |
| H3 | `form/cubit/task_form_cubit.dart:49-76`, `timeline/cubit/task_timeline_cubit.dart:12-33` | `emit` after `await` with no `isClosed` check. User pops the form (or dismisses the sheet) while the write/read is in flight → `StateError: Cannot emit new states after calling close` (unhandled async error). | **[by reading]** (bloc `emit` throws when closed) — prove with a test first |
| H4 | `data/repositories/task_repository_impl.dart:99-104` | `StorageFailure(error.toString())` puts raw exception text (`DatabaseException(...)`, SQL, `InjectedWriteException: …`) into user-visible SnackBars and the full-screen error. | **[by reading]** |
| H5 | `task_repository_impl.dart:49,61,73,86,94-97` | `_changesController.add(null)` runs inside the `try` **after commit**; if `dispose()` closed the controller meanwhile, `add` throws and the already-committed write is reported as `Failed`. Report-vs-stored mismatch violates the failure contract. | **[by reading]**; related probe: write racing `dispose()` returns `Failed(database_closed)` |

### Medium

| ID | Where | Problem |
|---|---|---|
| M1 | `data/fault/write_fault_injector.dart:56-77` | `TestFaultInjector` (test double) lives in production `lib/`. Move to `test/support/`. |
| M2 | `data/database/app_database.dart:15-18, 52-55, 58-64` | Memoised open future: if `_open()` throws before its first `await`, the `catch` nulls `_dbFuture` and then `??=` assigns the failed future → permanently cached failure (no retry). `close()` awaits a possibly-failed future and can throw. |
| M3 | `data/models/task_model.dart:10-13` | Unknown/corrupt `priority` silently becomes `medium` (`orElse`), while `TaskEventModel` throws on unknown type → inconsistent; hides data corruption. |
| M4 | `task_repository_impl.dart:48` (+ create path) | `create()` returns a `Task` with a *local* `createdAt`, reloads return UTC → equal tasks compare `!=` (`DateTime` equality includes `isUtc`). Normalise `now` to UTC in the repository. |
| M5 | `presentation/list/bloc/task_list_bloc.dart:131-143` + `task_list_page.dart:100-105` | `NotFoundFailure` ("Task no longer exists") still offers a **Retry** that can never succeed. Retry only makes sense for `StorageFailure`. |
| M6 | `task_list_bloc.dart:119-125`, `task_form_cubit.dart:57` | `Result<dynamic>` erases types (works only because strict-inference is satisfied by explicit `dynamic`). Use a typed helper returning `Failure?`. |
| M7 | `domain/entities/task_query.dart:17-18` | `isActive` uses untrimmed `text`, datasource uses trimmed → a whitespace-only search shows the "filtered" UI/Clear button while nothing is filtered. |
| M8 | `datasources/task_local_datasource.dart:191` | `delete(id, now)` has an unused `now` parameter and a second redundant checkpoint. |
| M9 | tests | Gaps: `ConfiguredFault`; form page failure → single SnackBar → Retry → pop; list page failure SnackBar Retry dispatches `retryEvent`; cubit closed mid-flight; `AppDatabase` retry after failed open; `TaskModel` corrupt row. Only one widget test exists (smoke). |

### Hygiene

| ID | Problem |
|---|---|
| L1 | Mixed import styles: 14 files use `package:niksam/…`, 19 use relative `../`. Pick one (choose **package imports**; enable `always_use_package_imports`). |
| L2 | `mocktail` and `cupertino_icons` are declared but unused (README even lists mocktail). `bloc_test` is used by one file only. `pubspec.yaml` still says `description: "A new Flutter project."`. |
| L3 | `MyApp` default name; `_ownsRepo` should be `final`. |

### Documentation / honesty (affects 40 % of the grade)

| ID | Problem |
|---|---|
| D1 | `README.md` prerequisites say "Flutter 3.24.x (Dart ^3.5.x)" but `pubspec.yaml` requires `sdk: ^3.12.2` (built with Flutter 3.44.6). README lists `mocktail` (unused). "Why LIKE is ASCII-only: to avoid external C extensions" is not a real rationale. |
| D2 | `README` Started/Finished (06:27 → 06:49, "~22 min") do not match git (`initial` 06:11, plan commit 06:26) and are not provably the human's real start/end. **HUMAN INPUT.** |
| D3 | `AI_WORKFLOW.md`: tools/models line ("Google Antigravity / Gemini 3.8 Flash / Claude 3.5 Sonnet") and "Key prompts" 2-5 look reconstructed, not real; **"What I Verified Myself" is fully ticked by the AI** although the manual checklist (PLAN P7) was never run by a human; the 3 "AI was wrong" entries are trivial import-depth typos (low signal); the file exceeds the 1-page limit (running log). **HUMAN INPUT.** |
| D4 | `DESIGN.md` is well over the 1–2 page limit (full SQL + two diagrams + long prose); §7 references a non-existent `repo.emitChange()` and says "without altering repository contracts" while needing a new emit path; add the *known limitations* in §Known limitations below. |
| D5 | Manual verification (PLAN P7 checklist) has no evidence anywhere. The UI has never been exercised by a human or driven on a device in this repo. |

---

## 2. Progress tracker

| ✔ | Phase | Fixes | Commits |
|---|---|---|---|
| [ ] | F1 Fault injector: per-operation attempts + tests | H1, M1 | 1 |
| [ ] | F2 Repository & DB hardening | H4, H5, M2, M3, M4, M8 | 1 |
| [ ] | F3 Presentation correctness | H2, H3, M5, M6, M7 | 1 |
| [ ] | F4 Widget & regression tests | M9 | 1 |
| [ ] | F5 Hygiene | L1, L2, L3 | 1 |
| [ ] | F6 Run it for real (device) — **HUMAN-assisted** | D5 | 0–n |
| [ ] | F7 Docs honesty & trimming — **HUMAN INPUT** | D1–D4 | 3 |
| [ ] | F8 Final gate | — | 1 |

---

## 3. Phases

### F1 — Fault injector: per-operation attempts (H1, M1)

**Test first** (`test/features/tasks/data/fault/configured_fault_test.dart`), watch it fail on the current code, then fix:
- `failWrites: true` → every attempt throws `InjectedWriteException` at its first checkpoint.
- `failFirstWrites: 2`, 5 sequential attempts → exactly the first 2 fail, the rest pass.
- `failFirstWrites: 1`, two attempts started **before** either reaches a checkpoint (interleaved) → exactly 1 fails.
- An attempt that never reaches a checkpoint (an `Unchanged` no-op) does **not** consume the budget.
- Defaults (`false`, `0`) never throw.
- Repository-level: `ConfiguredFault(failFirstWrites: 1)` → first `create` fails and rolls back (no task, no event), retry with the **same id** succeeds with exactly one `Created` event.

**Implementation**
1. Change the contract to per-operation objects:
   ```dart
   abstract interface class WriteFaultInjector { WriteAttempt beginWrite(); }
   abstract interface class WriteAttempt { void checkpoint(String name); }
   ```
2. `ConfiguredFault`: keep `int _failuresLeft = failFirstWrites`. `beginWrite()` returns an attempt that decides **lazily on its first `checkpoint`**: `failWrites` → throw; else if `_failuresLeft > 0` → `_failuresLeft--` and throw; otherwise pass (remember the decision so later checkpoints of the same attempt are consistent). No shared counter is read at checkpoint time.
3. `NoFault` returns a no-op attempt. In `TaskLocalDataSource` use `final attempt = faultInjector.beginWrite();` and `attempt.checkpoint(...)` everywhere (all four writes).
4. Move `TestFaultInjector` to `test/support/test_fault_injector.dart` (adapt to the new interface: `failAtCheckpoints`, `failNextWrite`, `writeCount`) and update the imports in the two test files.

**Commit:** `fix(data): make fault injection per-operation and move test injector out of lib`

---

### F2 — Repository & database hardening (H4, H5, M2, M3, M4, M8)

1. **H4 friendly messages.** Add `final String? details` to `StorageFailure` (not in `props` message equality concerns: keep `message` in `props`; `details` is diagnostic only). `TaskRepositoryImpl` maps by operation: reads → `"Couldn't load your tasks."`, writes → `"Couldn't save the change. Nothing was modified — please retry."`, `InjectedWriteException` → keep an explicit `"Simulated write failure (FAIL_WRITES). Nothing was saved."` (intentional dev feature, reviewers should see it). Log the raw error with `dart:developer` `log(…)`; never put it in `message`. Update tests that assert messages.
2. **H5.** Add `_notifyChanged()` → `if (!_changesController.isClosed) _changesController.add(null);` and call it **outside** the protected `try` result path (a notification problem must never change a committed result). Make `dispose()` idempotent. Test: dispose between commit and notification does not turn `Success` into `Failed`.
3. **M2.** Rewrite the memoisation so a failed open can always be retried and `close()` is safe:
   ```dart
   Future<Database> get database => _dbFuture ??= _open().catchError((Object e) { _dbFuture = null; throw e; });
   ```
   (remove the `try/catch` that nulls inside `_open`). `close()`: if `_dbFuture != null`, `try { (await _dbFuture!).close() } catch (_) {}` then null it. Test: factory that throws on the first open and succeeds on the second → second `database` call succeeds.
4. **M3.** `TaskModel.fromMap`: unknown priority → throw `ArgumentError` like `TaskEventModel` (no silent `orElse`). Test with a corrupt row → repository `getTasks` returns `Failed(StorageFailure)`.
5. **M4.** `TaskRepositoryImpl._now = (now ?? DateTime.now)` wrapped to return `.toUtc()`; update tests (`fixedNow` is already UTC). Assert `create()` result `==` the task later returned by `getTasks`.
6. **M8.** Remove the unused `now` parameter from `TaskLocalDataSource.delete` (+ repo call) and the redundant second checkpoint (keep `after_task_write`).

**Commit:** `fix(data): harden error mapping, disposal, database open retry and UTC handling`

---

### F3 — Presentation correctness (H2, H3, M5, M6, M7)

1. **H3 (test first):** cubit tests — start `submit` with a repo whose `create` is held by a `Completer`, `await cubit.close()`, complete the completer → no uncaught error (`runZonedGuarded` collects none). Same for `TaskTimelineCubit.load`. Fix: `if (isClosed) return;` after every `await` before `emit` (also guard the first `emit`s defensively).
2. **H2 (test in F4, fix here):** `TaskFormPage` listener → `listenWhen: (p, c) => p.status != c.status || p.token != c.token`. Also let `priorityChanged`/`titleEdited` reset a `failure` status back to `editing` so state matches what the user sees.
3. **M5:** make `ActionFailure.retryEvent` nullable; `NotFoundFailure` produces an `ActionFailure` **without** a retry event; the SnackBar shows the Retry action only when `retryEvent != null`. Keep the reload. Update the bloc test for the failure path (add a NotFound case).
4. **M6:** replace `Result<dynamic>` with a small private helper in each class, e.g. `Future<Failure?> _run(TaskMutationRequested e)` (returns `null` on success) so no `dynamic` remains.
5. **M7:** `TaskQuery.isActive` → `text.trim().isNotEmpty || …`. Unit test for whitespace-only text.

**Commit:** `fix(ui): guard emits after close, stop duplicate error snackbars, no retry for missing tasks`

---

### F4 — Widget & regression tests (M9)

Use `FakeTaskRepository` (extend it with configurable failing `create/update`). Keep them small and focused:
1. **Form failure flow:** submit with a failing repo → exactly **one** SnackBar with a Retry action; change priority → still one (regression for H2); make the fake succeed → tap Retry → page pops.
2. **Form validation:** empty title → inline error, repo not called.
3. **List failure flow:** a failing `setCompleted` → SnackBar with message (the friendly one, not raw exception text) and Retry; tapping Retry re-dispatches (fake sees the second call).
4. **List empty variants:** no tasks vs. filter-with-no-match shows "Clear filters".
5. Anything not already present from F1–F3 (AppDatabase retry, corrupt row) — verify they exist, don't duplicate.

**Commit:** `test(ui): add widget tests for form and list failure and retry flows`

---

### F5 — Hygiene (L1–L3)

1. Add `always_use_package_imports` to `analysis_options.yaml`; run `dart fix --apply`; then `dart format lib test`. Update `CLAUDE.md` (one line: "package imports only").
2. `flutter pub remove mocktail cupertino_icons`; keep `bloc_test` (used). Fix `pubspec.yaml` `description`.
3. Rename `MyApp` → `NiksamApp` (update `main.dart` and the widget test); `_ownsRepo` → `late final bool`.

**Commit:** `chore: unify imports, drop unused dependencies and rename app widget`

---

### F6 — Run it for real (HUMAN-assisted, ~15 min) (D5)

The agent runs what it can; the human taps through the UI. Devices available: Pixel 8 Pro (Android 15 emulator `127.0.0.1:6562`), Linux desktop.
1. `flutter run -d linux` (or the Pixel) — confirm it launches, no console errors.
2. Walk the PLAN **P7 manual checklist** (persistence after kill/relaunch; fast typing; combined filters kept after edit; `--dart-define=FAIL_WRITES=true` → every write errors, list unchanged, relaunch without flag shows no partial data; `--dart-define=FAIL_FIRST_WRITES=1` → first fails, Retry succeeds, exactly one event; 10 fast Complete taps → one `Completed` event; no-change save → no new event).
3. Fix each bug found in its own `fix:` commit (+ regression test). Record the **human's own** observations (what was checked, what surprised them) in `AI_WORKFLOW.md → What I verified myself`.

**Commit (only if a doc/log change):** `docs: record manual verification results`

---

### F7 — Documentation honesty & trimming (HUMAN INPUT) (D1–D4)

Ask the human first for: real start time, real finish time, tools + model names actually used, the prompts they actually typed (or confirm the real ones), what they personally verified.

**7a — README (`docs: correct README setup, packages and timing`)**
- Prerequisites: Flutter 3.44.x / Dart ^3.12 (match `pubspec.yaml`), platforms Android/iOS (+ desktop via FFI), web unsupported.
- Packages table: remove `mocktail`/`cupertino_icons`; keep rationale one line each.
- Limitations: replace the invalid LIKE rationale with the truth (SQLite `LIKE` is case-insensitive for ASCII only); add the *Known limitations* from §4 below.
- Started/Finished = the **human's real** timestamps with timezone; total time computed from them. If it was <3 h say so plainly; don't pad or invent.

**7b — DESIGN.md (`docs: trim DESIGN.md to two pages and fix sync section`)**
- Cut to ≤ 2 pages: keep one architecture diagram, **one** sequence diagram, the tables schema as a 6-line summary (not full SQL), and the seven required sections. Move long SQL to a one-line pointer to `migrations.dart`.
- §7 sync: replace `repo.emitChange()` with accurate wording — remote pulls are applied by the sync layer through the same local repository write path (transactional), which emits `changes`; the repository interface gains a sync-facing API, but the UI contract does not change.
- Add a short "Known limitations / trade-offs" list (§4 below).

**7c — AI_WORKFLOW.md (`docs: rewrite AI_WORKFLOW with verified facts`)** (≤ 1 page)
- Tools/models: only what the human confirms.
- Key prompts: real ones, quoted.
- **Where the AI was wrong** — replace the three import-typo entries with the substantive ones from this review that were actually fixed (cite fix commits): H1 (fault-counter race: tests were green because they used a different injector — `ConfiguredFault` had no tests), H2 (listener without `listenWhen`), H3/H5 (emit-after-close, notify-after-dispose), H4 (raw exception text in UI). Say honestly they were found in an independent review pass, not by the original run.
- **What I verified myself**: only items the human actually did (F6). Un-tick everything else.
- Move the long "Running log" to `docs/ai-running-log.md` and link it.

---

### F8 — Final gate

`flutter analyze` 0 issues · `flutter test` green · `dart format --set-exit-if-changed lib test` clean · README times filled by the human · `git log` shows the F-phase commits on top of the originals (no rewrite) · push.

**Commit:** `chore: final review pass`

---

## 4. Known limitations — document, do **not** fix (time/benefit)

- List rebuild: a change to `tasks` rebuilds the visible `TaskTile`s (closures are recreated); `ListView.builder` builds only visible rows, so cost is negligible at this scale. Filters/search field/form fields do not rebuild the list (`buildWhen`/`BlocSelector`).
- "Clear filters" and the search ✕ dispatch debounced/multiple events (≤ 300 ms lag, up to 3 cheap queries); correctness is protected by the `state.query` guard. A dedicated immediate event would need care so a pending debounced search cannot resurrect old text.
- `SearchField` is cleared through a `GlobalKey` (`clearText`) — pragmatic; a `BlocListener` on `query.text` would be purer.
- Sorting depends on device clock (events ordered by `occurred_at, id`); LIKE is ASCII-case-insensitive; no pagination; no undo for delete; web unsupported.
- No form-level "discard changes?" prompt; no in-flight indicator on the Complete checkbox.
