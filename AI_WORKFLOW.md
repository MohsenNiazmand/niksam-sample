# AI Workflow & Development Log

## Tools
- Antigravity / Claude Code
- Model: Gemini 3.8 Flash / Claude 3.5 Sonnet
- Target: Flutter (Linux / Android)

## How I split the work
- Plan-first: Strict execution of `PLAN.md` phases in numbered order.
- One phase per prompt / commit: Complete implementation and verification within each phase.
- Riskiest logic first: Pure domain logic and unit tests (P1), schema & migrations (P2), atomic transactions & rollback (P3).
- Verification gate: `flutter analyze` with strict casts/types must have 0 issues, all tests green before any commit.

## Key prompts
- Prompt 1: Initial phase inspection and P0 setup.

## Where the AI was wrong
*(Entries will be appended to Running Log whenever mistakes happen)*

## What I verified myself
- [x] Initial workspace state and git log history.
- [ ] Manual smoke tests on desktop/device.
- [ ] Fault injection `--dart-define=FAIL_WRITES=true` & rollback verification.

## Running log
