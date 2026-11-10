# Niksam — Offline Task Manager

An offline-first Flutter task manager built with SQLite, BLoC pattern, and full activity history. Designed to demonstrate atomic transactions, idempotent operations, and failure simulation with zero data corruption.

- **Started:** 2026-11-10 14:41 (Asia/Tehran, UTC+03:30)
- **Finished:** 2026-11-10 15:55 (Asia/Tehran, UTC+03:30)
- **Total Development Time:** ~1 h 14 min (including the review-and-fix pass), within the 3-hour time box

---

## Architecture & Documentation
- [DESIGN.md](DESIGN.md) — Comprehensive architecture, atomicity proofs, and decision records
- [PLAN.md](PLAN.md) — Phased implementation plan and progress tracker
- [CLAUDE.md](CLAUDE.md) — Architectural rules and code standards
- [AI_WORKFLOW.md](AI_WORKFLOW.md) — AI pair programming prompts, corrections, and audit log

---

## Getting Started

### Prerequisites
- **Flutter:** 3.44.x / Dart ^3.12.2
- **Platforms:** Linux, macOS, Windows, Android, iOS (**Web is unsupported** due to raw SQLite FFI requirement)

### Setup & Run Commands
```bash
# 1. Fetch dependencies
flutter pub get

# 2. Run static analyzer (strict mode: strict-casts, strict-inference, strict-raw-types)
flutter analyze

# 3. Run all unit, bloc and integration tests
flutter test

# 4. Run normally
flutter run

# 5. Run with simulated permanent write failures
flutter run --dart-define=FAIL_WRITES=true

# 6. Run with transient failure (first write fails, retry succeeds)
flutter run --dart-define=FAIL_FIRST_WRITES=1
```

> **Note on Desktop:** On Linux, macOS, and Windows, SQLite FFI is initialized automatically at startup via `sqflite_common_ffi`.

---

## Dependencies & Packages

| Package | Purpose & Selection Rationale |
|---|---|
| `flutter_bloc` | State management separating UI from business logic with fine-grained reactive rebuilding. |
| `bloc_concurrency` | Event transformers: `sequential()` for atomic write ordering and `restartable()` for queries. |
| `stream_transform` | Provides `debounce()` for search query throttling. |
| `equatable` | Value equality for states, events, and domain entities with complete `props`. |
| `sqflite` / `sqflite_common_ffi` | Embedded SQLite engine supporting raw SQL, explicit `db.transaction`, and `PRAGMA` controls. |
| `path` | Cross-platform file path manipulation. |
| `uuid` | Client-side UUID v4 generation ensuring write idempotency upon failure retries. |
| `bloc_test` *(dev)* | Deterministic state transition testing for BLoCs and Cubits. |

---

## Limitations & Unfinished Scope
1. **Case-Insensitive Search**: SQLite `LIKE` operator is case-insensitive for ASCII characters only. Non-ASCII text is matched case-sensitively.
2. **Device Clock Dependency**: Event ordering relies on the device's UTC clock (`DateTime.now().toUtc()`).
3. **No Pagination**: The task list loads matching tasks for the current query directly from SQLite into memory.
4. **No Undo on Hard Delete**: Deleted tasks and cascaded timelines are immediately purged from SQLite.
5. **Web Unsupported**: Requires SQLite C bindings via FFI.
