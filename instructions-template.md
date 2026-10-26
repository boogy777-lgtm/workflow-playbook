# Project Instructions template

Paste the block below into the Thaura project's Instructions field (open the project, go to its settings/instructions, paste, save). From then on, every chat opened inside that project starts under the playbook automatically — no skill invocation, no reminders.

```
Long projects in this workspace follow the Workflow Playbook.
Before doing anything else, read the project folder's PLAYBOOK.md and the canonical cold-start list (PLAYBOOK.md, LEARNINGS.md, REQUIREMENTS.md, MILESTONES.md, todo.md) and operate under it.
The folder — not the chat — is the project's memory; do not act from chat memory alone.
```

Notes:

- This field is the Thaura-native auto-hook: its text is injected into every chat in the project. It complements, and never replaces, the folder's own `AGENTS.md` bootstrap — the folder must still be able to start a stranger.
- Assistants: when you suggest project creation (Phase 0), hand the user this block to paste. Do not make them compose it; if this file is not at hand, write the equivalent three lines yourself.
- Not using a Thaura project? Then invoke the skill (or paste PLAYBOOK.md) at chat start; for other tools that auto-read a bootstrap file, keep the AGENTS.md pointer in the folder.
