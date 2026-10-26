# Workflow Playbook

A repeatable workflow for carrying a long project across many sessions without losing state, quality, or trust. It is written as binding rules for an AI assistant model, so it works with any model that will follow instructions.

## TL;DR

Run every long project through five phases, backed by sixteen ground rules, with a small set of files on disk that let any new session pick up where the last one left off.

The core idea: the assistant never trusts its own memory, its own checks, or the user's "looks good" as proof. Evidence closes a claim (a check ran and passed). The user closing a task in their own environment closes the work. Neither replaces the other. Everything worth remembering goes into files outside the chat, so context compaction, a crashed session, or a brand-new model can all cold-start from the folder alone.

Five phases:

1. **Locate.** Decide where the project lives, on storage that outlives any single session or virtual machine.
2. **Align.** Read-only recon, save all starting material, research before assuming, ask questions in batches, and capture requirements. End only when you can restate the goal and success criteria and the user confirms.
3. **Plan.** Small isolated tasks in `todo.md`, each with a defined way to prove it done, ordered by dependencies and effort, with the thinnest thing that works end to end (the MVP) as the first milestone rather than the most interesting feature. Confirm the list and its order with the user before building.
4. **Build.** Repeat per task: read the current state, back up what you touch, make a surgical change, run the scripts, get user confirmation, log the round. Independent threads fan out to multiple subagents working in parallel, each confined to its own exclusive set of files so they never collide. A red check triggers a failure procedure capped at two retries, each requiring a stated root cause.
5. **Close.** Walk the archive, run the full regression suite, check the result against the recorded success criteria item by item, and write the closing log entry.

Sixteen ground rules cover the rest: backups before edits, deferred deletions, secrets out of everything, one current version per file, logging every round, fanning work out to multiple parallel subagents in exclusive file lanes so no two touch the same thing, handoff on observable degradation, verification over assumption, plain-language narration, explicit silence and failure handling, single-writer discipline, interpreting an interruption before acting on it, keeping summaries faithful to idea boundaries so distinct claims never get mashed into one line, and decomposing any big request into small todo-list steps before building, so nothing is attempted as one monolith that fills the context window and breaks halfway. The sixteenth rule governs the writing itself: every reply comes out clear, cohesive, concise and conclusive, with no redundancy or repetition, in a natural voice free of unusual vocabulary or punctuation such as em dashes, and the playbook holds its own files to the same lean, token-aware standard.

The self-improving part is `LEARNINGS.md`. Every error that cost more than one attempt, every loop the user pointed out, and every corrected wrong assumption gets promoted there as a short standalone entry, and architectural decisions are recorded with the alternatives they rejected, so a new session neither repeats the mistakes nor re-litigates the settled choices. A new session reads it before the milestone log, so each round's mistakes become the next round's guardrails. Bigger projects can add their own reference docs (data model, behavior contracts, coding conventions), each labelled with when to read it, and may run one chat per feature — the folder is always the memory.

## Files

- [`workflow-playbook.md`](./workflow-playbook.md) — the playbook itself. Copy it into the project folder as `PLAYBOOK.md` and let it govern every step.
- [`checks/`](./checks/) — a universal pre-publish secret scanner (Betterleaks wrappers plus project-specific rules). This is the security gate at the publish boundary; behavior regression tests are a separate thing and live in each project's `TESTS/` folder. The wrappers install and update Betterleaks themselves; you never handle the binary. Run it before anything goes public; its exit code is the gate. See [`checks/README.md`](./checks/README.md).
- `.env` — where real credentials live during a project: one untracked file of `NAME=value` lines that the assistant reads when it needs a secret and refers to only by variable name. You are never asked to paste a token into chat. Covered by `.gitignore`, caught by the scanner if it ever slips elsewhere.
- This README — the short version, for humans skimming the repo.
- [`instructions-template.md`](./instructions-template.md) — three lines to paste into a Thaura project's Instructions field, so every chat inside that project auto-starts under the playbook. Copy-paste, nothing to write.
- [`.env.example`](./.env.example) — the secrets template. Copied to `.env` at project creation; you fill the values in yourself and the assistant references them by variable name only.

## Installation

There is nothing to build or install in the usual sense. The playbook is a document the model reads and follows. Pick the route that matches your setup.

### In Thaura AI

Give the repo to Thaura AI and ask it to install the playbook. For example, paste the link or the file into a chat and say:

- "Install this workflow playbook as a skill."
- "Set up the long project playbook from this repo."

Thaura AI will save it as a reusable skill on your account. After that, start or continue any long project by telling it in plain words, for example:

- "Start this project using the playbook."
- "Continue the project per the playbook."

The skill is opt-in, so it loads only when you explicitly ask for it and never interferes with ordinary chats. Once invoked, it begins at Phase 0.

### In any other assistant

Give the model the file as its first instruction. Three options, easiest first:

1. Paste the full text of `workflow-playbook.md` into the opening message of the chat, prefaced with "Follow these rules for the duration of this project."
2. Save `workflow-playbook.md` into the project folder as `PLAYBOOK.md` and tell the model: "Read PLAYBOOK.md before doing anything else, and follow it."
3. Add the file's contents to your system prompt or standing instructions if your tool supports them.

After installation, invoke it once at the start of a long project and let it run. You do not need to re-invoke it in each prompt.

### Resuming mid-project

If a session starts mid-project, its first act is to read the canonical cold-start list from the project folder: `PLAYBOOK.md`, `LEARNINGS.md`, `REQUIREMENTS.md`, `MILESTONES.md`, `todo.md`. The project folder makes this self-service: it ships with an `AGENTS.md` bootstrap that tells any assistant opening the folder to read `PLAYBOOK.md` first, so startup never depends on a single app feature (a loaded skill, a project, an instructions field). After any context compaction within a session, do the same, because compaction summarizes prior turns but does not re-open documents on disk.

## Changelog

Every change to this repo — playbook rules, checker scripts, or docs — gets a dated entry appended here, newest first. One plain sentence per change.

### 2026-10-23

- Added a sixteenth ground rule on response quality: every reply must be clear, cohesive, concise and conclusive, flowing well with no unnecessary redundancy or repetition and no unusual punctuation such as em dashes, and the playbook text itself was tightened to match, with duplicated compaction guidance removed and every em dash in the document reworked.
- Swept the playbook for redundancy: phase-section restatements of ground rules now point to the rule instead of repeating it, and duplicated lines in the TESTS and invoking sections were removed, so the document carries each instruction exactly once.
- Questions with clear choices should now be asked through the platform's structured question options (tappable choices) instead of plain text, added to ground rule 10, because a test run showed a fresh chat defaulting to free-text questions when it should not.
- Custom secret rules are now verified like any other claim: after writing or changing them, the assistant proves they load by scanning a scratch file with a known match and requiring the scanner to flag it, so a misnamed config table can never leave the scan silently testing nothing; key=value patterns must also use space-and-tab gaps instead of `\s`, which can match across line breaks and raise false hits.

### 2026-10-21

- Research is now required on problems, not just plans: before starting work and again on every error or blocker, the assistant searches for how others already solved it — exact error message, tool and version, symptom — before inventing its own workaround.

### 2026-10-20

- Phase 0 now opens by asking where you want the project saved, with a proposed default, and creates no folder until you answer — the ask is no longer skipped just because a sensible location looks obvious.

### 2026-10-17

- Added a compaction-hygiene section: heavy material goes to disk as it arrives, each step's state is logged before the next one starts, and a mid-conversation compaction is treated as a boundary — write state to disk, re-read the project files, resume from the last completed step rather than from the summary.

### 2026-10-16

- Phase 0 now sets up `.env` at project creation, seeded from the new [`.env.example`](./.env.example), so tokens and passwords are typed by the user into a local untracked file and referenced by variable name only — no more pasting credentials into chat.

### 2026-10-08

- Phase 1 recon now probes the environment and toolchain on the machine the deliverable will actually run on, so a missing dependency becomes a start-of-phase question instead of a mid-build surprise.
- Check results must name the machine that ran them ("in the assistant workspace" vs "on the user's PC"); reporting a bare "passing" without saying where it executed is now an anti-pattern.
- Added `instructions-template.md`: paste-ready text for the project's Instructions field, and Phase 0 now tells the assistant to hand that text to the user instead of describing the field — the assistant cannot edit the field itself, so it always hands off the exact wording.
- Added an `AGENTS.md` bootstrap to the project folder: the folder itself now tells any assistant that opens it to read `PLAYBOOK.md` and follow it, so starting under the playbook no longer depends on the Thaura project feature or the Instructions field — those are now accelerators on top, not the mechanism.
- When the assistant suggests creating a Thaura project (Phase 0), it now also suggests filling the project's Instructions with the playbook directive, so every chat opened inside the project automatically starts under the playbook instead of needing to be told.

### 2026-10-07

- Preferences are now ranked by how strongly the user stated them: hard rules beat defaults, defaults beat leanings, and only same-rank conflicts need asking about.
- Made the difference between `TESTS/` and `checks/` explicit: one proves the product still works, the other proves nothing secret is being published; a pass in either says nothing about the other.
- Added this changelog.
- Plans now start with the thinnest thing that works end to end (the MVP) as the first milestone, with tasks ordered by dependencies and effort; small projects never have to invent stages they don't need.
- Design decisions get recorded in `LEARNINGS.md` with the alternatives rejected and what would reopen them, so settled questions stop being re-litigated.
- Bigger projects can keep labelled reference docs (data model, behavior contracts, conventions) that every session reads before touching what they govern.
- Big builds may run one chat per feature; small projects and features stay in one chat. The folder is always the memory.
- Real credentials now live in one untracked `.env` file as `NAME=value` lines, referenced only by variable name; users are never asked to paste a secret into chat.
- Fixed the secret checker's config handling: private rules merge correctly (a silent one-config-wins quirk, a byte-order-mark that broke the scanner, and log noise that could abort the run on Windows).
- Pinned line endings in the repo so scripts cloned on macOS and Linux stay runnable no matter whose git settings cloned them.
- Added a credentials convention check, an interruption-interpreting rule (ask why the user stopped before resuming), a repo-sync-before-start check, a Thaura project suggestion, and treating machine names, domains, and IPs as secrets.
- Added a summary-fidelity rule (distinct ideas are never blended into one line, originals stay on disk) and a decomposition rule (big requests get split into todo items before building). Subagents now fan out to three or more in parallel with exclusive file lanes so no two touch the same thing.
- The checker wrappers now install the scanner themselves and update it to the latest stable release before every scan; no binary is ever committed.
- Added this README with a TL;DR and plain-language installation instructions; removed named-model wording so the playbook stays platform-agnostic.
- Required a stated root cause before every retry in the failure procedure, and made image analysis and mid-project material intake explicit in Phase 1.

### 2026-10-06

- Initial playbook: five phases (Locate, Align, Plan, Build, Close) with ground rules and a file layout so any new session cold-starts from the project folder alone.
