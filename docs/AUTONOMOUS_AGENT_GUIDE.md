# Pocket Habitat — Autonomous Agent Guide

## Purpose and source of truth

This is the reusable operating guide for autonomous work. The repository, not an old handoff or run report, determines the current state and next task.

When information conflicts, trust this order:
1. Current source, configuration, tests, and Git history.
2. AGENTS.md.
3. docs/PROJECT_STATE.md for factual implementation and verification status.
4. docs/ROADMAP.md for priorities and acceptance criteria.
5. Relevant sections of docs/TECHNICAL_ARCHITECTURE.md.
6. docs/TESTING.md for reproducible checks and evidence.
7. Product/design documents for their specific subject.
8. Old prompts and run reports as historical context only.

Never copy an old run number, commit, completion claim, or model list forward without checking it against the current repository.

## Start every run — keep context bounded

1. Check the current branch, HEAD, and working tree. Preserve existing valid changes.
2. Start with the attached compact Pocket Habitat agent context when supplied. It summarizes the current task, state, roadmap, recovery debt, and latest verification evidence.
3. Use the context brief as a navigation index, then inspect only the relevant current sections of PROJECT_STATE.md, ROADMAP.md, TESTING.md, and AGENTS.md. Do NOT load the entire docs/TECHNICAL_ARCHITECTURE.md by default; locate headings and read only relevant narrow line ranges.
4. Inspect only the source modules, remote call sites, data structures, and tests needed for the selected vertical slice. Search first; read focused ranges.
5. Compare source with the current state and roadmap. Correct stale status rather than repeating it.

Context efficiency is a reliability requirement, not permission to skip engineering. Avoid loading the same document or source repeatedly, dumping entire directories, or attaching complete logs/diffs. Summarize evidence and inspect exact ranges. The configured low-limit models have small request budgets; keep initial context especially lean, and reduce context when a provider reports a request-size or input-token limit. Do not replay an unchanged oversized prompt.

Do not ask the user to repeat information already in the repository. Make a conservative documented decision unless an essential product choice is genuinely unknowable.

## Choose one valuable task

For a specific user request, implement that objective and necessary dependencies. For a generic continuation, choose the highest-value unfinished item in PROJECT_STATE and ROADMAP, normally in this order:
1. Player-data integrity, exploit prevention, multiplayer isolation, and persistence safety.
2. Broken or incomplete core gameplay paths.
3. Integration between habitats, plots, resources, plants, creatures, quests, upgrades, economy, and UI.
4. Repeatable tests and verification for high-risk behavior.
5. Player experience, accessibility, performance, and presentation.
6. Additional content and release preparation.

Prefer one complete, integrated vertical slice over broad disconnected scaffolding. A feature is not complete merely because a module, remote, constant, model, attribute, test, or UI element exists.

A meaningful development cycle must change project-owned runtime gameplay code or the runtime project mapping. Documentation-only, recovery-note-only, and test-only changes may support implementation but do not count as gameplay progress.

## Implementation and Roblox correctness

Trace the complete path: client input and presentation; remote invocation; server validation; ownership/session checks; state mutation and transaction ordering; rewards, inventory, currency, and progression; persistence/restoration; player feedback; and cleanup.

- Use Luau and the pinned Rojo/Rokit/Wally toolchain.
- Reuse the current architecture and production rules unless a verified limitation requires change.
- The server is authoritative. Treat all client values as untrusted. Validate types, ranges, ownership, session, target membership, server-measured distance, cooldowns, request frequency, inventory, currency, and gameplay state before mutation.
- Prevent cross-player access, duplicate rewards, double spending, remote spam, race conditions, and data loss.
- Never replace player data with defaults after a failed DataStore read. Preserve save compatibility and use explicit migrations.
- Make multi-step reward/economy operations transaction-safe.
- Verify uncertain Roblox API behavior against current official documentation and actual call sites.
- RemoteFunction:InvokeServer and RemoteEvent:FireServer automatically supply the requesting Player as the first server callback argument. Do not manually pass LocalPlayer as an extra argument.
- ProximityPrompt.Triggered supplies playerWhoTriggered; still validate the action server-side. Client prompt visibility is not a security boundary.
- Optimize for normal Roblox clients, including mobile. Prefer original, lightweight assets and document provenance.

## Pipeline boundaries

GitHub Actions owns provider/model routing, retries, cooldowns, implementation, independent review, repair, QA, deterministic validation, and persistence.

- Use configured routes. Do not hard-code model lists, call provider APIs directly, create nested agents, or manually reproduce pipeline stages.
- Do not change secrets, credentials, provider routing, or workflow configuration unless the current user task authorizes the change.
- A transient RPM/TPM limit, 429, 5xx, timeout, or capacity issue is not a gameplay defect. Do not claim remaining quota unless an authoritative balance was checked.
- The workflow cannot read live provider balances. It only marks quota exhausted after an explicit provider/model quota error.
- Keep prompts and tool outputs lean. If a provider rejects a request as too large or exceeds input tokens per minute, inspect the prompt/context size and remove irrelevant document/source output before retrying. Do not weaken review, QA, or deterministic checks to make a run green.
- The workflow applies run-wide temporary-limit caps; after repeated model/provider 429s, continue with other eligible routes rather than repeatedly retrying the same limited route.
- A successful handoff or recovery checkpoint is not validated development progress. Only implementation + independent review + deterministic validation + independent QA + successful checkpoint persistence counts as a validated cycle.
- Keep docs/AUTONOMOUS_RECOVERY.md as a compact current-task note (maximum 12 KB). Preserve full logs/diffs in workflow artifacts or docs/recovery-archive; never paste full transcripts into the active note.
- Resolve active source-level recovery debt before unrelated features. Mark RECOVERY_STATUS: RESOLVED only when every automation-resolvable item is fixed and concrete evidence is recorded. Keep Roblox Studio, multiplayer, DataStore, TestEZ, and device checks marked unverified when they were not executed.
- Respect bounded model-call, wait, cycle, and no-progress guards. Never disable a safety guard merely to force continuation. Report when human restart or provider reset is required.

## Branch and repository boundaries

Repository: Adventurehkus/pocket-habitat
- Gameplay source: ai/game-build
- Workflow/configuration: main

The workflow persists gameplay changes. Do not create or switch branches, commit/push manually, publish the Roblox experience, create releases, or access publishing credentials. Never modify DevPackages/_Index, vendored Wally dependencies, third-party source, or generated dependency caches. Format/lint only project-owned files under src; never run StyLua over the repository root.

## Testing and evidence

Run the checks supported by the current environment:
- rojo build default.project.json -o build/pocket-habitat.rbxl
- stylua --check src
- selene src
- git diff --check
- git status --short
- TestEZ only through a compatible runner.

Record exactly what ran and whether it passed, failed, was skipped, or was unavailable. Separate static checks, executed unit/integration tests, Roblox engine tests, and manual Studio/multiplayer testing. A Rojo build only proves a model file was generated; it does not prove the game is playable or release-ready.

## Living documentation

Keep these documents accurate:
- docs/PROJECT_STATE.md: implemented, partial, unverified, broken, known risks, and exact next task.
- docs/ROADMAP.md: milestone state, acceptance criteria, priorities, and current focus.
- docs/TECHNICAL_ARCHITECTURE.md: actual architecture and known gaps.
- docs/TESTING.md: commands and real verification evidence.
- docs/AUTONOMOUS_RECOVERY.md: compact active recovery debt.
- IMPLEMENTATION_SUMMARY.md: concise latest meaningful implementation checkpoint.

Preserve history but label it historical. Do not leave stale current-status claims or invent test results, commits, artifacts, or completed features.

## Required handoff

Report:
1. What was implemented and what works end-to-end.
2. Important files and architecture changes.
3. Exact checks and their results.
4. Roblox Studio, multiplayer, persistence, TestEZ, mobile, or manual gaps.
5. Risks and unfinished work.
6. Build artifact/upload status only when confirmed.
7. One highest-value next task consistent with PROJECT_STATE and ROADMAP.

Be concise, factual, and do not claim release readiness from static checks alone.
