# Pocket Habitat — Autonomous Agent Operating Guide

## Purpose

This document defines the durable operating procedure for every autonomous development run. It is intentionally independent of milestone numbers, run numbers, commit hashes, model names, provider availability, and temporary implementation priorities.

The repository is the source of truth. The reusable handoff prompt tells the agent to follow this guide; the live project state and roadmap determine what to do next. Do not require the user to rewrite a milestone-specific prompt after each successful run.

## Source-of-truth hierarchy

When information conflicts, use this order:

1. The current checked-out source, project configuration, tests, and actual Git history.
2. AGENTS.md for repository-wide constraints.
3. docs/PROJECT_STATE.md for the latest factual implementation and verification snapshot.
4. docs/ROADMAP.md for priorities, milestone acceptance criteria, and the current next task.
5. docs/TECHNICAL_ARCHITECTURE.md for the current architecture and intended boundaries.
6. docs/TESTING.md for test commands, actual results, and known verification gaps.
7. Game/design/asset/monetization documents for product intent in their respective areas.
8. Previous run reports and handoff prompts as historical context only.

If a document disagrees with the source, inspect the source and correct the document. Never copy an old commit hash, run number, model list, or implementation claim forward without verifying it.

## Run initialization

At the beginning of every implementation run:

1. Inspect the current branch, working tree, and latest commit. Do not assume the starting revision from a previous prompt.
2. Read AGENTS.md, this guide, docs/PROJECT_STATE.md, docs/ROADMAP.md, docs/TECHNICAL_ARCHITECTURE.md, and docs/TESTING.md.
3. Read the relevant design documents and inspect the actual source modules, call sites, remotes, data structures, and tests before editing.
4. Identify changes made since the last recorded checkpoint. Preserve correct work and avoid repeating completed tasks.
5. Check whether the roadmap's stated next task is still the highest-value incomplete task. Update it when new evidence changes the priority.

Do not ask the user to repeat information already present in the repository or conversation. Ask a question only when a genuinely essential product decision cannot be safely inferred. Otherwise, make a conservative, documented engineering decision and proceed.

## How to choose work

### When the user supplies a specific task

Treat the user's task as the immediate objective, subject to security, repository, and platform constraints. Inspect how it fits the architecture and roadmap. Implement it completely enough to integrate with the existing game. If it reveals a more serious correctness or data-safety problem, address that dependency first and explain the scope adjustment in the handoff.

### When the user supplies a generic continuation request

Do not invent a new milestone. Select the highest-priority unfinished item from docs/PROJECT_STATE.md and docs/ROADMAP.md using this order:

1. Player-data integrity, exploit prevention, cross-player isolation, and persistence safety.
2. Broken or incomplete core gameplay paths that block a usable game loop.
3. Integration gaps between existing systems (habitat, plots, resources, plants, creatures, quests, upgrades, economy, UI).
4. Missing tests and repeatable verification for high-risk functionality.
5. Player experience, accessibility, performance, and visual polish.
6. Additional content, optional features, and release preparation.

This order is a guide, not a substitute for examining current evidence. A verified critical regression takes precedence over planned feature work.

Choose one coherent, achievable vertical slice. Prefer a working end-to-end path over broad scaffolding. Do not scatter unfinished code across unrelated systems to make a milestone appear larger.

### Dynamic milestone rule

Milestone numbers and next tasks are maintained in docs/ROADMAP.md and docs/PROJECT_STATE.md. They are not permanently embedded in this guide or the reusable prompt.

After completing or materially advancing a task:
- Update the actual milestone status and acceptance criteria.
- Record what is implemented, partially implemented, or still only planned.
- Select the next task from the remaining evidence-backed gaps.
- Leave enough context for the next run to continue without the user rewriting the prompt.

A milestone is not complete merely because files, constants, remotes, models, or UI elements exist. Completion requires integrated gameplay and appropriate verification.

## Implementation workflow

1. **Inspect:** Trace the complete path from client input through remotes, server validation, state mutation, persistence, and player feedback.
2. **Design minimally:** Reuse existing production rules and modules. Make the smallest architecture change that safely enables the required behavior.
3. **Implement:** Build a complete vertical slice with server-authoritative ownership and failure handling.
4. **Test:** Add or extend tests against production logic. Run every compatible deterministic check available.
5. **Review locally:** Inspect the full diff for regressions, unrelated edits, secrets, generated files, and vendored changes.
6. **Document:** Update only the documents affected by real changes and verification.
7. **Handoff:** State exact outcomes, remaining risks, and the next evidence-backed task.

Do useful implementation work throughout the available execution budget. Do not spend most of a run rewriting plans or duplicating this guide. If the whole milestone is too large, complete the strongest coherent slice and document the next step.

## Engineering standards

- Use Luau and the pinned Rojo/Rokit/Wally toolchain.
- Preserve the existing project architecture unless a verified limitation justifies a change.
- Keep gameplay and rewards server-authoritative.
- Treat every client argument as untrusted. Validate type, range, ownership, distance, session state, cooldown, and request frequency on the server.
- Never trust client-supplied UserIds, instance ownership attributes, progress, reward amounts, currency balances, or completion flags as proof of authorization.
- Make multi-step economy and reward operations transaction-safe. Prevent duplicate rewards, double-spending, race conditions, and cross-player data access.
- Treat DataStore failures differently from genuinely absent records. Never replace existing player data with defaults after a failed read.
- Preserve existing save compatibility and use explicit schema migrations for changes.
- Use bounded, observable retry logic for external services. Never hide persistent failures.
- Optimize for ordinary Roblox clients, including mobile devices.
- Prefer original, licensed, lightweight assets and document their provenance.
- Do not claim a feature is complete just because it builds.

## Roblox API correctness

Verify uncertain Roblox APIs against current official documentation and the actual call site. Do not blindly accept model-generated review suggestions.

For client RemoteFunction calls, Roblox supplies the requesting Player as the first argument to the server's OnServerInvoke callback. Do not manually pass LocalPlayer as an extra InvokeServer argument. The same automatic Player parameter applies to the server OnServerEvent callback for FireServer.

For ProximityPrompt.Triggered, use the playerWhoTriggered parameter from the event and still validate the action on the server. Client prompt visibility or properties are not security boundaries.

## Multi-model pipeline and temporary limits

The GitHub Actions workflow owns model selection, provider routing, implementation/review/repair/QA orchestration, quota classification, automatic cooldowns, retry scheduling, validation, and persistence.

- Use only the configured model/provider routes supplied by the workflow and repository configuration.
- Do not hard-code model lists or assume a particular provider is available.
- Do not call provider APIs directly, create nested agents, or manually reproduce the pipeline's stages.
- Do not change provider configuration, secrets, credentials, model routing, or the GitHub Actions workflow unless the user's current task explicitly authorizes that work.
- Do not treat a temporary RPM/TPM limit, 429, transient 5xx, timeout, or capacity error as a code defect.
- The workflow classifies provider errors, applies per-model/provider cooldowns, honors retry hints, tries other routes, and automatically revisits temporary failures within bounded retry and job-time budgets.
- Standard live runs execute repeated autonomous cycles: implementation, independent review, conditional repair, deterministic validation, and independent QA. After a validated cycle, the workflow pushes a checkpoint to `ai/game-build` before beginning the next cycle.
- Candidate models rotate between cycles. A successful model is excluded from other roles during that same cycle so implementation, review, and QA remain independent, then becomes eligible again in later cycles unless its quota or run budget is exhausted.
- The run continues beyond the first successful implementation/review/QA sequence. The quota-exhaustion target is **100% of currently eligible quota pools**: every pool that remains usable for this run must return an explicit daily/monthly quota-exhaustion error before quota-target completion, subject to hard safety caps.

- The eligible-pool percentage is calculated as confirmed-exhausted pools divided by confirmed-exhausted plus still-eligible pools. Permanently ineligible routes (for example, invalid credentials, unavailable models, or requests too large for that model) are excluded from the eligible denominator; they are not counted as quota-exhausted.
- If there are no measurable exhausted or eligible pools, report 0% and do not declare the target reached. If any hard safety cap, validation failure, or no-progress guard stops the run first, report that exact stop reason and clearly state that the 100% quota target was not reached.

- Quota pools are estimates based on current routing: Google/Groq models are counted separately; Cohere, OpenRouter, Cloudflare, and Copilot routes are grouped by provider/account. The workflow cannot query true provider balances; it only knows a pool is exhausted after receiving an explicit provider/model quota error. This is not an exact balance meter.
- Temporary RPM/TPM limits are cooled down and revisited later. Explicit daily/monthly/shared quota exhaustion disables the affected scope for the rest of the run. Authentication failures, unavailable models, request-size failures, and unknown errors are excluded from eligible pools; they do not count as daily quota exhaustion.
- Current hard limits: 8 calls per model per run, 120 total model calls, 30 autonomous cycles, at most 2 hours of aggregate temporary-limit waiting, and the GitHub Actions job's 350-minute timeout. The run also stops after two consecutive implementation cycles produce no repository changes, or if review, QA, deterministic validation, or checkpoint persistence cannot complete safely.
- Never tell the user that a provider has remaining quota unless an authoritative account balance was actually queried. Configured models do not imply available quota.

A single pasted task is used for the first cycle. Later cycles continue that task if it remains incomplete; otherwise they choose the next highest-priority unfinished item from the live project state and roadmap. The workflow cannot continue after the GitHub Actions job has ended; if a hard budget is reached before the quota target, the report must state that stop reason.

**Billing caution:** a quota-focused run makes substantially more API calls than the previous one-pass workflow. Whether an individual provider call is free depends on the connected account/project billing configuration, which the workflow cannot inspect. Confirm provider free-tier status and configure hard spending limits with providers before running. The workflow's call caps limit request count, not dollar spend.

## Repository and Git boundaries

Repository: Adventurehkus/pocket-habitat

Gameplay source branch: ai/game-build  
Workflow/configuration branch: main

The workflow persists implementation changes to ai/game-build. Do not create or switch branches, commit manually, push manually, publish the Roblox experience, create releases, or access publishing credentials.

Never modify or format:
- DevPackages/_Index/
- Vendored Wally dependencies.
- Third-party source or generated dependency caches.

Only format and lint project-owned Luau files under src/. Never run StyLua over the repository root.

Do not download GitHub ZIP archives or repository bundles. Read repository text through the available GitHub file/content tools and inspect only files needed for the task.

## Testing and evidence

Run the available project checks, typically:

- Parse project/configuration files where relevant.
- rojo build default.project.json -o build/pocket-habitat.rbxl
- stylua --check src
- selene src
- git diff --check
- git status --short

Run TestEZ only through a compatible runner. Do not infer that specs passed because they exist or because Wally installed TestEZ.

Separate these categories in every report:
- Static checks actually executed.
- Unit/integration tests actually executed.
- Roblox engine tests actually executed.
- Manual Studio/client/multiplayer tests actually executed.
- Tests written but not executed.
- Checks unavailable in the environment.

A successful Rojo build proves that a model file was built. It does not prove gameplay works, multiplayer isolation is safe, or the game is release-ready.

## Documentation contract

Keep these documents synchronized with source truth:

- AGENTS.md: concise permanent repository rules and pointers to this guide.
- docs/AUTONOMOUS_AGENT_GUIDE.md: durable run procedure and engineering policy.
- docs/PROJECT_STATE.md: factual current implementation, verification, risks, and exact next task.
- docs/ROADMAP.md: evolving milestone status, acceptance criteria, priority order, and current focus.
- docs/TECHNICAL_ARCHITECTURE.md: actual architecture, intended architecture, and known gaps.
- docs/TESTING.md: reproducible commands, actual test status, and historical verification records.
- Other design documents: update only when product/design intent changes.

Preserve historical run records, but clearly label them historical. Do not leave stale claims in current-status sections. Never invent commit hashes, CI runs, test output, or completion status. After each meaningful implementation run, update PROJECT_STATE.md and ROADMAP.md if status or next priority changed.

## Required final handoff

Report:
1. What changed and what works end-to-end.
2. Important changed files and architectural impact.
3. Exact checks run and their pass/fail/skip/unavailable status.
4. What remains unverified in Roblox Studio, multiplayer, persistence, or mobile.
5. Known risks, regressions, or incomplete integrations.
6. Artifact path and upload status only when confirmed.
7. The single highest-value next task, synchronized with the roadmap.

Keep the report factual and concise. Never imply release readiness from static checks alone.