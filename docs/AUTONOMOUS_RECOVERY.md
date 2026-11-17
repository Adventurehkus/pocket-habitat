# Pocket Habitat — Active Recovery Summary

RECOVERY_STATUS: OPEN

- Last updated from workflow run: 139
- Failed run: 139 (2026-11-17), autonomous cycles 1–2
- Current gameplay branch: `ai/game-build`

## Current blocker

Run 137 had already left an independent-QA evidence gate open: code review returned a valid decision, but neither QA route returned the required `QA_BLOCKER: YES` or `QA_BLOCKER: NO` decision. Run 139 did not clear that gate. It failed earlier, during implementation, so review, QA, deterministic source validation, and checkpointing of a gameplay change were never reached.

Run 139 evidence:
- 13 quota pools were configured; 9 carried reset/cooldown state, leaving 4 eligible pools.
- The four eligible routes attempted were Gemini 4 Gemma 31B, Gemini 4 Gemma 26B A4B, Groq Qwen 3.8 27B, and Groq GPT-OSS 20B.
- The run made 23 model calls and spent 410 seconds in automatic cooldown waits, but made no repository changes and completed 0/30 validated cycles.
- Google free-tier input-token-per-minute limits were hit by both Gemma routes.
- Groq explicitly rejected requests above per-minute request ceilings: Qwen ITPM 7,000 with 9,026 requested; Qwen OTPM 1,000 with 1,242 requested; GPT-OSS 20B TPM 8,000 with requests between 9,016 and 11,292.
- The run stopped at the two-consecutive-zero-progress circuit breaker. It did not reach independent review, QA, or the main deterministic validation stage. The initial toolchain Rojo build, model-registry check, and continuation-policy preflight passed.

## Workflow repairs committed on main

The run-139 evidence showed avoidable routing/retry waste. The workflow was updated to:
1. Classify explicit Groq per-request `Limit / Requested` TPM failures as `REQUEST_TOO_LARGE` before the generic TPM cooldown matcher, preventing repeated requests that cannot fit.
2. Set Groq Qwen 3.8 27B and GPT-OSS output caps to 800 tokens, below the observed 1,000-token OTPM ceiling.
3. Replace only the recognized full evergreen handoff input with a short continuation instruction, since the permanent engineering instructions already live in repository documents.
4. Increase the consecutive zero-progress continuation limit from 2 to 5. This remains bounded and does not mark a handoff as development progress.
5. Add regression fixtures for Groq ITPM, OTPM, combined TPM request-size errors, and ordinary retryable TPM throttles; add a model-registry preflight check for Groq output caps.

Latest workflow fix commit: `faba3c85437bdaf742ffbc0f0262cbe826bee71c` on `main`.

## Required next action

Dispatch a fresh workflow run so the committed workflow/configuration changes are actually exercised. It must:
- Retry the compacted evergreen task through currently eligible routes.
- Produce an implementation that is reviewed, source-validated, QA-checked, and checkpointed before it counts as progress.
- Revisit the unresolved Run 137 baseline-QA gate. Require a valid `QA_BLOCKER: YES/NO` decision and resolve any confirmed blocker before changing this file to `RECOVERY_STATUS: RESOLVED`.

Do not mark this recovery resolved based on the classifier fixture test, a successful workflow handoff, a successful Rojo bootstrap build, or a run that makes no gameplay changes. The workflow edits have not yet been exercised by a new Actions run.

## Verification boundaries

- Run 139: initial toolchain Rojo build PASS; provider/model registry preflight PASS; existing continuation-policy test PASS.
- Current-session classifier regression fixtures for Groq ITPM, OTPM, combined TPM and ordinary retryable throttles: PASS.
- New GitHub Actions Groq model-registry assertion and five-run continuation-policy tests: committed, but NOT YET EXECUTED in Actions.
- Gameplay implementation, independent review, main deterministic validation, QA: NOT RUN in run 139.
- TestEZ, Roblox Studio, multiplayer, DataStore, save/rejoin, shutdown, and manual testing: NOT RUN / still unverified.

## Historical Run 137 QA evidence gap

Run 137's compact note recorded:
- `opencode-review-31.log` (1029 bytes): independent review passed.
- `pocket-habitat-implementation.diff` (0 bytes): no implementation changes.
- `pocket-habitat-validation.log` (201 bytes): validation artifact; QA transcripts/provider diagnostics were not recorded in the compact note.

The later workflow diagnostics fix preserves QA transcripts and attempted provider/model details for future failures. Run 139 supersedes Run 137 as the latest failed execution, but does not erase its still-open QA requirement.

## Related source-restoration work

The previously corrupted `src/shared/PocketHabitat.spec.lua` was restored from intact revision `6cfdc9ea061b8c80ab2a93651b11cc97b81187a8`, and the empty `src/shared/PocketHabitat.spec.lua.restored` placeholder was removed. Those source-level repairs remain complete but do not satisfy the current independent-QA gate.

Do not claim TestEZ, Roblox Studio, multiplayer, DataStore, save/rejoin, or shutdown tests passed unless they are actually executed.

Archive: docs/recovery-archive/AUTONOMOUS_RECOVERY_2026-11-15_PRE_COMPACTION.md
