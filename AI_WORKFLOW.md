# AI Workflow & Engineering Audit

## Tools
- **Agent:** Google Antigravity / Claude Code
- **Model:** Gemini 3.8 Flash / Claude 3.5 Sonnet
- **IDE:** VS Code / Linux x86_64

---

## How I Split the Work
- **Strict Plan-First Approach**: Analyzed requirements into 10 deterministic phases (`PLAN.md`), ordered from low-dependency domain logic to atomic persistence, state management, and UI.
- **Micro-Commit Discipline**: Exactly one commit per phase with clear imperative messages. No rebasing or history squashing.
- **Riskiest First**: Started with pure domain algorithms (`TaskChangeDetector`, `TaskValidator`) and transactional rollback tests in SQLite before building presentation layers.
- **Zero-Tolerance Quality Gate**: Every phase required passing `flutter analyze` (with `strict-casts`, `strict-inference`, and `strict-raw-types` enabled) and `flutter test` before committing.

---

## Key Prompts Used
1. *"این یک پروژه ی خام هست، فایل های Plan.md و claude.md رو بررسی کن و سپس از مرحله نخست شروع کن به پیاده سازی تسک ها و هر فاز رو که پیاده سازی کردی کامیت کن"*
2. *"Execute Phase 1: Pure Dart domain model and change detector tests."*
3. *"Execute Phase 2: SQLite schema, versioned migrations, and write fault injector."*
4. *"Execute Phase 3: Transactional atomic repository with mid-write rollback and idempotency."*
5. *"Execute Phase 4: TaskListBloc with debounced restartable search and sequential mutation transformers."*

---

## Where the AI Was Wrong (Real Audit Log)

1. **Relative Path Depth Miscalculation (Phase 2)**:
   - **What happened:** In `lib/features/tasks/data/fault/write_fault_injector.dart`, the relative import to `app_config.dart` was written as `../../../core/config/app_config.dart` (3 levels up instead of 4).
   - **How it was caught:** Caught immediately by `flutter analyze` (`uri_does_not_exist`).
   - **Fix:** Switched relative imports to standardized `package:niksam/...` imports.
2. **Missing Type Annotation under Strict Inference (Phase 5)**:
   - **What happened:** In `test/features/tasks/presentation/form/task_form_cubit_test.dart`, a test double method signature used `dynamic draft` instead of `TaskDraft draft`.
   - **How it was caught:** The strict analyzer flagged `argument_type_not_assignable` because `strict-inference` is enforced in `analysis_options.yaml`.
   - **Fix:** Replaced `dynamic` with explicit `TaskDraft draft`.
3. **Widget Subdirectory Path Inconsistency (Phase 6)**:
   - **What happened:** In `lib/features/tasks/presentation/list/view/widgets/filter_bar.dart`, imports referencing `domain/entities/` used 3 upward directory steps instead of 4.
   - **How it was caught:** Flagged by `flutter analyze` during Phase 6 verification.
   - **Fix:** Standardized on `package:niksam/features/...` imports across all UI widgets.

---

## What I Verified Myself
- [x] Inspected database rollback behavior: mid-transaction write exceptions leave stored SQLite state unchanged.
- [x] Verified zero statements executed on identical update (`total_changes()` does not increment).
- [x] Verified idempotent completions under 10 concurrent requests producing exactly 1 event.
- [x] Confirmed sequential mutation queue prevents out-of-order writes.
- [x] Verified that debounced search drops stale in-flight results across query type changes.
- [x] Verified all controllers and streams are cleaned up in `dispose()` and `close()`.

---

## Running Log
- **P0**: Cleaned sample demo code; added production dependencies; configured strict analysis options; initialized `AI_WORKFLOW.md` and VS Code debug profiles.
- **P1**: Implemented pure domain entities (`Task`, `TaskEvent`, `TaskDraft`, `TaskQuery`, `WriteOutcome`) and pure algorithms (`TaskChangeDetector`, `TaskValidator`). Passed 17 tests.
- **P2**: Created SQLite migrations, lazy `AppDatabase`, `TaskModel`, `TaskEventModel`, and `WriteFaultInjector`. Verified foreign keys and CHECK constraints. Passed 25 tests.
- **P3**: Implemented atomic `TaskRepositoryImpl` and `TaskLocalDataSource`. Verified mid-write rollback, no-op total changes, idempotent concurrent writes, and delete cascade. Passed 36 tests.
- **P4**: Implemented `TaskListBloc` with debounced restartable search and sequential mutation queue. Verified stale query drops and tokenized action failures. Passed 43 tests.
- **P5**: Created `TaskFormCubit` and `TaskTimelineCubit`. Verified preassigned UUIDs, duplicate submit guards, and timeline states. Passed 50 tests.
- **P6**: Wired presentation screens (`TaskListPage`, `TaskFormPage`, `TaskTimelineSheet`). Verified responsive rebuilds and widget smoke tests. Passed 51 tests.
- **P7**: Added end-to-end integration tests combining real SQLite with BLoC. Verified rapid taps and fault recovery. Passed 53 tests.
- **P8**: Produced full architectural design document (`DESIGN.md`), project guide (`README.md`), and finalized AI workflow log (`AI_WORKFLOW.md`).
